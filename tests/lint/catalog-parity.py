#!/usr/bin/env python3
"""Does every version the package catalog pins actually exist in its registry?

The catalog profiles are the fleet's answer to "what IS a machinery cluster".
They are unit-tested for shape (xplane-crossplane-catalog/catalog_test.k) — but
a unit test cannot know whether `cluster:v0.6.1` can be pulled. Nothing here
can: the pin is a string, and a string is always well-formed.

WHY THIS RUNS ON A SCHEDULE AND NOT ONLY ON CHANGES.

The catalog drifts WITHOUT ANYONE TOUCHING IT. Its pins name packages built in
other repositories; every release there moves the fleet forward and leaves the
profile where it was. A check gated on catalog changes would therefore never
fire on the failure it exists for.

Measured, not assumed (2026-08-20): the machinery profile had fallen four
Configurations behind the reference cluster — cluster v0.4.0 vs v0.6.1, platform
v0.3.11 vs v0.6.2, proxmoxvm v0.11.0 vs v0.12.2, vspherevm v0.9.0 vs v0.9.2 —
and carried no harvester-vm at all. Nobody noticed for weeks. It surfaced only
when a freshly built LabDA seed came up on cluster v0.4.0, which knows neither
`harvester` in the provider enum nor the vault-labda mapping, and therefore
could not build the very clusters it had been stood up for.

TWO SEVERITIES, AND THE SPLIT IS DELIBERATE.

  pin does not exist        ERROR    A machinery cluster built from this profile
                                     cannot come up. The package manager will
                                     sit on ErrImagePull and every XRD the
                                     package carries is simply absent.

  pin behind newest         WARNING  Pinning IS the point of a catalog; being
                                     behind is legitimate and often correct.
                                     What is not acceptable is being behind
                                     WITHOUT KNOWING, which is exactly what
                                     happened. So this prints a table on every
                                     run — the delta is meant to be read, not
                                     to fail a build.

An unreachable registry is SKIPPED, never reported. A check that goes red when
a registry has a bad day gets switched off, and then it checks nothing at all.

Usage:
    python3 tests/lint/catalog-parity.py [--catalog crossplane/xplane-crossplane-catalog]
    python3 tests/lint/catalog-parity.py --strict   # behind-newest fails too
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

TIMEOUT = 10
SEMVER = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")

# Emitted into the catalog module so `kcl run` resolves its own imports. Reading
# the pins through KCL rather than regexing the .k source means a profile that
# builds its package list any other way still gets checked.
DUMP = """import main as c

out = [
    {profile = n, name = p.name, kind = p.kind, package = p.package}
    for n in c.names for p in c.catalog[n].packages
]
"""


def parse_semver(tag: str):
    m = SEMVER.match(tag)
    return tuple(int(g) for g in m.groups()) if m else None


def load_pins(catalog: Path) -> list[dict]:
    """Every (profile, package) pin, via `kcl run` rather than text parsing."""
    with tempfile.NamedTemporaryFile("w", suffix=".k", dir=catalog,
                                     delete=False) as fh:
        fh.write(DUMP)
        tmp = Path(fh.name)
    try:
        proc = subprocess.run(["kcl", "run", tmp.name, "--format", "json"],
                              cwd=catalog, capture_output=True, text=True)
        if proc.returncode != 0:
            print(proc.stderr.strip(), file=sys.stderr)
            raise SystemExit("catalog-parity: `kcl run` failed — cannot read pins")
        return json.loads(proc.stdout)["out"]
    finally:
        tmp.unlink(missing_ok=True)


def split_ref(ref: str) -> tuple[str, str, str] | None:
    """`host/path:tag` -> (host, path, tag). None if it is not that shape."""
    if ":" not in ref or "/" not in ref:
        return None
    path, _, tag = ref.rpartition(":")
    host, _, repo = path.partition("/")
    if "." not in host or not repo:
        return None
    return host, repo, tag


def _token(host: str, challenge: str) -> str | None:
    """Bearer token from a WWW-Authenticate challenge (the standard OCI dance).

    Doing this generically rather than special-casing ghcr.io is what lets the
    check cover the Functions and Providers too: those live on xpkg.upbound.io
    and xpkg.crossplane.io, and a Function pinned to a version that was never
    released breaks a cluster exactly as thoroughly as one of ours.
    """
    parts = dict(re.findall(r'(\w+)="([^"]*)"', challenge))
    realm = parts.pop("realm", None)
    if not realm:
        return None
    query = "&".join(f"{k}={v}" for k, v in parts.items())
    try:
        with urllib.request.urlopen(f"{realm}?{query}" if query else realm,
                                    timeout=TIMEOUT) as r:
            body = json.load(r)
        return body.get("token") or body.get("access_token")
    except Exception:
        return None


# `Link: </v2/…/tags/list?last=…>; rel="next"` — the OCI distribution spec's
# pagination cursor.
NEXT_PAGE = re.compile(r'<([^>]+)>\s*;\s*rel="next"')

# Backstop for a registry that never stops handing out cursors. 50 pages is
# 5000 tags; no package here is near that, and looping forever inside CI is a
# worse failure than an incomplete answer.
MAX_PAGES = 50


class NotPublic(Exception):
    """The registry answered that there is nothing anonymously pullable here.

    Distinct from "unreachable", and the distinction is load-bearing: a pin
    nobody can pull breaks a cluster exactly as thoroughly whether the package
    was never pushed or merely left private, and BOTH must be reported. A
    private package silently skipped is the failure this check exists to catch.

    Measured on ghcr.io (2026-08-20), which separates the two at the token
    endpoint: 403 = never pushed, 401 = exists but private. `task push` reports
    success for the second; only the visibility flip is missing.
    """

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


def fetch_tags(host: str, repo: str) -> list[str] | None:
    """Published tags, [] if the repository has none/does not exist, None if the
    registry declined to answer.

    None and [] must stay distinguishable: a timeout reported as "never
    published" would accuse every pin in the catalog the moment a registry
    hiccups.

    PAGINATED, AND THAT IS NOT OPTIONAL. Registries cap a tag list — xpkg.
    crossplane.io returns exactly 100 with a `Link: rel="next"` — and the cap
    bites hardest on the packages with the most releases, which are the
    crossplane-contrib Functions. Reading only the first page reported
    function-auto-ready v0.6.5, function-go-templating v0.12.2 and
    function-environment-configs v0.7.2 as "does not exist" while all three were
    running on the reference cluster. A check that fails CI on three correct
    pins is worse than no check; found while writing this one.
    """
    url = f"https://{host}/v2/{repo}/tags/list"
    token: str | None = None
    tags: list[str] = []
    try:
        for _ in range(MAX_PAGES):
            headers = {"Authorization": f"Bearer {token}"} if token else {}
            try:
                r = urllib.request.urlopen(
                    urllib.request.Request(url, headers=headers), timeout=TIMEOUT)
            except urllib.error.HTTPError as e:
                if e.code != 401 or token is not None:
                    raise
                token = _token(host, e.headers.get("WWW-Authenticate", ""))
                if not token:
                    # The realm refused to mint an anonymous token. For a public
                    # repository it always does; a refusal therefore means the
                    # artifact is not publicly pullable, which is an ANSWER.
                    raise NotPublic(
                        "no anonymous token — the repository is private or "
                        "does not exist") from None
                continue
            with r:
                tags.extend(json.load(r).get("tags") or [])
                link = NEXT_PAGE.search(r.headers.get("Link", "") or "")
            if not link:
                return tags
            nxt = link.group(1)
            url = nxt if nxt.startswith("http") else f"https://{host}{nxt}"
        return tags
    except urllib.error.HTTPError as e:
        # 401/403/404 are ANSWERS: no public artifact under this name. GHCR in
        # particular does not 404 for a package that was never pushed — it
        # answers 403 at the token step, and 401 for one that exists but is
        # private. Both belong in the report; only a registry that declines to
        # answer at all (5xx, rate limit) is a skip.
        if e.code in (401, 403, 404):
            raise NotPublic(f"registry answered {e.code}") from None
        return None
    except Exception:
        return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--catalog", default="crossplane/xplane-crossplane-catalog",
                    help="path to the catalog module")
    ap.add_argument("--strict", action="store_true",
                    help="treat 'behind newest' as an error too")
    args = ap.parse_args()

    catalog = Path(args.catalog).resolve()
    if not (catalog / "kcl.mod").exists():
        print(f"catalog-parity: no kcl.mod under {catalog}", file=sys.stderr)
        return 1

    pins = load_pins(catalog)
    errors: list[str] = []
    behind: list[tuple[str, str, str, str]] = []
    skipped: list[str] = []

    for pin in pins:
        ref = pin["package"]
        parts = split_ref(ref)
        if parts is None:
            errors.append(f"{pin['profile']}/{pin['name']}: "
                          f"{ref!r} is not host/path:tag")
            continue
        host, repo, tag = parts

        try:
            tags = fetch_tags(host, repo)
        except NotPublic as e:
            errors.append(
                f"{pin['profile']}/{pin['name']}: {host}/{repo}:{tag} is not "
                f"anonymously pullable ({e.reason}) — a cluster built from this "
                f"profile cannot install it")
            continue
        if tags is None:
            skipped.append(f"{host}/{repo}")
            continue

        if tag not in tags:
            published = sorted(filter(None, (parse_semver(t) for t in tags)))
            newest = "v" + ".".join(map(str, published[-1])) if published else "none"
            errors.append(
                f"{pin['profile']}/{pin['name']}: pinned {tag} does not exist in "
                f"{host} (newest published: {newest}) — a cluster built from this "
                f"profile cannot pull it")
            continue

        pinned = parse_semver(tag)
        published = sorted(filter(None, (parse_semver(t) for t in tags)))
        if pinned and published and published[-1] > pinned:
            newest = "v" + ".".join(map(str, published[-1]))
            behind.append((pin["profile"], pin["name"], tag, newest))

    if behind:
        print("Pins behind the newest published version:")
        width = max(len(f"{p}/{n}") for p, n, _, _ in behind)
        for profile, name, tag, newest in behind:
            print(f"  {f'{profile}/{name}':<{width}}  {tag:>10}  ->  {newest}")
        print()

    for e in errors:
        print(f"ERROR {e}")

    if skipped:
        print(f"note: skipped {len(skipped)} repo(s), registry unreachable: "
              f"{', '.join(sorted(set(skipped)))}", file=sys.stderr)

    print(f"catalog-parity: {len(pins)} pin(s), {len(errors)} error(s), "
          f"{len(behind)} behind newest")

    return 1 if errors or (args.strict and behind) else 0


if __name__ == "__main__":
    sys.exit(main())
