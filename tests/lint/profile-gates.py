#!/usr/bin/env python3
"""Do the cluster profiles still switch what the ArgoCD catalog selects on?

A profile in xplane-cluster-catalog/profiles.k is a set of cluster LABELS, and
the ApplicationSets in stuttgart-things/argocd platforms/ decide what those
labels install. catalog_test.k pins the labels themselves; it cannot know what
the other repository does with them.

WHY THIS RUNS ON A SCHEDULE, like catalog-parity: the catalog drifts without
anyone touching it. The ArgoCD catalog is consumed from MAIN, so an AppSet added
or renamed there changes every cluster that carries the umbrella at once -- and
the change is in a repository this workflow does not watch.

The platform AppSets are OPT-OUT: `<umbrella>: "true"` plus
`<umbrella>/<component> NotIn ["false"]`, and a Kubernetes NotIn also matches a
cluster that does not carry the key. So a component the profile does not name
is ON. Two failures follow from that, and both are silent on the cluster:

1. A label no AppSet selects on (ERROR). A profile's "false" for a gate that was
   renamed upstream switches off nothing, and the component it meant is back
   under its new name. Holds for every profile; no intent needed.

2. An EXCLUSIVE profile that no longer is (ERROR). `kargo` takes Kargo alone
   from platforms/cicd, so every other opt-out gate under cicd-platform must be
   "false" in it (stuttgart-things/stuttgart-things#3232). An AppSet added there
   is installed on app-dev until it is listed. Intent cannot be read from the
   labels -- `network` leaves most of its umbrella on deliberately -- so it is
   declared in EXCLUSIVE below, with what the profile keeps.

An unreachable ArgoCD catalog is SKIPPED, never reported, for catalog-parity's
reason: a check that goes red when GitHub has a bad day gets switched off.

Usage:
    python3 tests/lint/profile-gates.py
    python3 tests/lint/profile-gates.py --argocd-dir ../argocd   # a local tree
"""
from __future__ import annotations

import argparse
import io
import json
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

import yaml

CATALOG = Path("crossplane/xplane-cluster-catalog")
ARGOCD = "https://codeload.github.com/stuttgart-things/argocd/tar.gz/refs/heads/main"
TIMEOUT = 60

# profile -> the opt-out components of its umbrella it deliberately keeps ON.
# Every other opt-out gate under that umbrella must be "false" in the profile.
EXCLUSIVE = {
    "kargo": {"kargo"},
}


def load_profiles(catalog: Path) -> dict:
    """The profile table through `kcl run`, as the module itself evaluates it."""
    proc = subprocess.run(["kcl", "run", "profiles.k", "-S", "profileTable",
                           "--format", "json"],
                          cwd=catalog, capture_output=True, text=True)
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        raise SystemExit("profile-gates: `kcl run` failed -- cannot read the profiles")
    return json.loads(proc.stdout)


def fetch_argocd() -> Path | None:
    """stuttgart-things/argocd at main, or None if it cannot be reached."""
    try:
        with urllib.request.urlopen(ARGOCD, timeout=TIMEOUT) as r:
            blob = r.read()
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        print(f"profile-gates: SKIP -- cannot fetch the ArgoCD catalog: {e}")
        return None
    dest = Path(tempfile.mkdtemp(prefix="argocd-"))
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tf:
        try:
            tf.extractall(dest, filter="data")
        except TypeError:
            tf.extractall(dest)
    (root,) = list(dest.iterdir())
    return root


def _selectors(gens):
    for g in gens or []:
        if isinstance(g, dict):
            if "clusters" in g:
                yield (g["clusters"] or {}).get("selector") or {}
            for nested in ("matrix", "merge"):
                if nested in g:
                    yield from _selectors((g[nested] or {}).get("generators"))


def gates(tree: Path) -> tuple[set, dict]:
    """(every label key an AppSet selects on, {umbrella: {opt-out component}})."""
    selected, optout = set(), {}
    for f in sorted((tree / "platforms").glob("*/appset-*.yaml")):
        try:
            docs = list(yaml.safe_load_all(f.read_text()))
        except yaml.YAMLError:
            continue
        for d in docs:
            if not isinstance(d, dict) or d.get("kind") != "ApplicationSet":
                continue
            for sel in _selectors((d.get("spec") or {}).get("generators")):
                selected |= set((sel.get("matchLabels") or {}))
                for e in sel.get("matchExpressions") or []:
                    key = e.get("key", "")
                    selected.add(key)
                    if e.get("operator") == "NotIn" and list(e.get("values") or []) == ["false"] \
                            and "/" in key:
                        umbrella, _, comp = key.partition("/")
                        optout.setdefault(umbrella, set()).add(comp)
    return selected, optout


def umbrella_of(profile: dict) -> str | None:
    """The platform a profile turns on -- the rule xplane-cluster uses."""
    on = [k for k, v in profile["labels"].items()
          if k.endswith("-platform") and "/" not in k and v == "true"]
    return on[0] if on else None


def check(profiles: dict, selected: set, optout: dict) -> list[str]:
    errors = []
    for name, p in sorted(profiles.items()):
        for key in sorted(p["labels"]):
            if key not in selected:
                errors.append(f"{name}: sets {key!r}={p['labels'][key]!r}, and no AppSet "
                              f"in stuttgart-things/argocd platforms/ selects on it -- "
                              f"renamed or removed upstream? A \"false\" for a renamed gate "
                              f"leaves the component ON under its new name.")
    for name, keep in sorted(EXCLUSIVE.items()):
        if name not in profiles:
            errors.append(f"EXCLUSIVE names {name!r}, which the catalog has no profile "
                          f"for -- drop the entry")
            continue
        labels = profiles[name]["labels"]
        umbrella = umbrella_of(profiles[name])
        comps = optout.get(umbrella, set())
        if not comps:
            errors.append(f"{name}: no opt-out gate under {umbrella!r} in platforms/ -- "
                          f"the umbrella moved, and this check checks nothing")
            continue
        for comp in sorted(comps - keep):
            if labels.get(f"{umbrella}/{comp}") != "false":
                errors.append(f"{name}: {umbrella}/{comp} is an opt-out gate the profile "
                              f"does not switch off, so every cluster with {name!r} "
                              f"installs it. Add \"{umbrella}/{comp}\" = \"false\" to the "
                              f"profile, or keep it deliberately in EXCLUSIVE.")
        for comp in sorted(keep):
            if comp not in comps:
                errors.append(f"{name}: keeps {umbrella}/{comp}, which is no opt-out gate "
                              f"in platforms/ -- renamed upstream?")
            elif labels.get(f"{umbrella}/{comp}") == "false":
                errors.append(f"{name}: keeps {comp} and switches it off")
    return errors


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalog", type=Path, default=CATALOG)
    ap.add_argument("--argocd-dir", type=Path,
                    help="a local stuttgart-things/argocd tree instead of main")
    args = ap.parse_args()

    profiles = load_profiles(args.catalog)
    tree = args.argocd_dir or fetch_argocd()
    if tree is None:
        return 0
    selected, optout = gates(tree)
    if not selected:
        raise SystemExit(f"profile-gates: no ApplicationSet selector under {tree}/platforms "
                         f"-- wrong tree, not a clean result")

    errors = check(profiles, selected, optout)
    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)
    print(f"profile-gates: {len(profiles)} profile(s), {len(selected)} selected label(s), "
          f"exclusive: {', '.join(sorted(EXCLUSIVE))} -- {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
