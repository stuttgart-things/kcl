#!/usr/bin/env python3
"""One module version = one OCI tag = one git tag = one template state.

claim-machinery-api profiles are to pin their template URLs to a git tag of
this repository (stuttgart-things/claim-machinery-api#153) instead of
`refs/heads/main`. That only works if a tag means something: the tag
`<module>-<version>` points at the commit whose module directory was published
as `ghcr.io/stuttgart-things/<module>:<version>`, and whose templates carry
`spec.tag: <version>`. Two rules make that hold:

  check-bump   (pull request) a change to a module's released files needs a
               new `version` in its kcl.mod, and every ClaimTemplate under
               <module>/templates must carry `spec.tag` == that version.
               Seen without it: kcl#412 changed native-vm-labda-vsphere.yaml,
               xr-native-vm stayed 0.4.0 -- OCI 0.4.0 and the template on main
               no longer described the same thing.

  tag-target   (publish on main) the commit the tag `<module>-<version>` has
               to point at: the pushed commit when the version was just
               published, otherwise (version already in the registry, tag
               missing: a backfill) the commit that set the version -- and
               only if the module's released files did not change since.
               Anything else is an error; a tag is never guessed.

Released files: everything under the module directory except Markdown and
tests/ (they do not change what `kcl run` renders or what a profile serves).

Usage:
  module-release.py check-bump --base <sha> --head <sha> <module-dir>...
  module-release.py tag-target --sha <sha> [--published] <module-dir>
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def released(path):
    """Does this file change what the module releases?"""
    p = Path(path)
    return p.suffix.lower() != ".md" and "tests" not in p.parts


def version_at(module, rev):
    try:
        mod = git("show", f"{rev}:{module}/kcl.mod")
    except subprocess.CalledProcessError:
        return None  # the module did not exist at rev
    m = re.search(r'^version\s*=\s*"([^"]+)"', mod, re.M)
    return m.group(1) if m else None


def name_of(module):
    m = re.search(r'^name\s*=\s*"([^"]+)"', (ROOT / module / "kcl.mod").read_text(), re.M)
    return m.group(1)


def template_tags(module):
    """[(file, spec.tag)] of the ClaimTemplates that render THIS module."""
    out = []
    oci = f"oci://ghcr.io/stuttgart-things/{name_of(module)}"
    for f in sorted((ROOT / module / "templates").glob("*.y*ml")):
        for doc in yaml.safe_load_all(f.read_text()):
            if isinstance(doc, dict) and doc.get("kind") == "ClaimTemplate" \
                    and (doc.get("spec") or {}).get("source") == oci:
                out.append((f.relative_to(ROOT), str(doc["spec"].get("tag"))))
    return out


def changed(module, base, head):
    files = git("diff", "--name-only", base, head, "--", module).split()
    return [f for f in files if released(f)]


def check_bump(args):
    fail = []
    for module in args.modules:
        module = module.rstrip("/")
        if not (ROOT / module / "kcl.mod").exists():
            continue  # removed in this change
        new = version_at(module, args.head)
        old = version_at(module, args.base)
        files = changed(module, args.base, args.head)
        if files and old is not None and new == old:
            fail.append(f"{module}: released files changed ({', '.join(files)}) "
                        f"but kcl.mod is still {new} -- bump the version")
        for f, tag in template_tags(module):
            if tag != new:
                fail.append(f"{f}: spec.tag {tag} != kcl.mod version {new}")
        print(f"{module}: {old} -> {new}, {len(files)} released file(s) changed")
    for f in fail:
        print(f"FAIL {f}", file=sys.stderr)
    return 1 if fail else 0


def tag_target(args):
    module = args.module.rstrip("/")
    version = version_at(module, args.sha)
    if args.published:
        print(args.sha)
        return 0
    # Backfill: the version is in the registry already. The tag belongs on the
    # commit that set it -- if nothing released changed since.
    setter = git("log", "-1", "--format=%H", f"-G^version = \"{re.escape(version)}\"",
                 args.sha, "--", f"{module}/kcl.mod").strip()
    if not setter:
        print(f"FAIL {module}: no commit sets version {version}", file=sys.stderr)
        return 1
    files = changed(module, setter, args.sha)
    if files:
        print(f"FAIL {module}: {version} is published from {setter[:9]}, but released files "
              f"changed since ({', '.join(files)}) -- bump the version instead of tagging", file=sys.stderr)
        return 1
    print(setter)
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("check-bump")
    b.add_argument("--base", required=True)
    b.add_argument("--head", required=True)
    b.add_argument("modules", nargs="+")
    t = sub.add_parser("tag-target")
    t.add_argument("--sha", required=True)
    t.add_argument("--published", action="store_true")
    t.add_argument("module")
    args = ap.parse_args()
    return check_bump(args) if args.cmd == "check-bump" else tag_target(args)


if __name__ == "__main__":
    sys.exit(main())
