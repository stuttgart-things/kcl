# CLAUDE.md

## Project Overview

KCL modules repository for Crossplane, Kubernetes, Flux, Helm, and related technologies. All modules are published as OCI artifacts to `ghcr.io/stuttgart-things/`.

## Repository Structure

- `models/` - Reusable KCL model modules (CRD-based)
- `crossplane/` - Crossplane composition and claim modules
- `flux/` - Flux Kustomization and operator modules
- `kubernetes/` - Kubernetes resource modules
- `tests/` - Module tests and usage examples

## Key Tasks (Taskfile.yaml)

### push-module

Pushes a KCL module to the OCI registry with version management.

**Interactive (gum-based):**
```bash
task push-module
```

**Non-interactive:**
```bash
task push-module MODULE_DIR=flux/claim-flux-kustomizations NEW_VERSION=0.3.4
```

| Variable | Description |
|---|---|
| `MODULE_DIR` | Path to KCL module directory (relative to repo root) |
| `NEW_VERSION` | Semver version without `v` prefix (e.g. `0.3.4`) |

Uses Dagger module `github.com/stuttgart-things/dagger/kcl` for push. Requires `GITHUB_USER` and `GITHUB_TOKEN` env vars.

**Fallback (direct push without Dagger):**
```bash
cd <module-dir>
kcl mod push oci://ghcr.io/stuttgart-things/<module-name>
```

### lint-repository

```bash
task lint-repository
```

Lints the repo using Dagger blueprint function.

### Other Tasks

- `task create` - Create a new KCL module (interactive)
- `task create-object-module-from-crd` - Convert CRDs to KCL modules (interactive)
- `task tag` - Tag and push a git release

## OCI Registry

All modules are published to `ghcr.io/stuttgart-things/<module-name>`. Check existing versions:

```bash
oras repo tags ghcr.io/stuttgart-things/<module-name>
```

## Publishing credentials

CI publishes with `GHCR_TOKEN` (a PAT with `write:packages`) when that secret is
set, and falls back to `GITHUB_TOKEN` when it is not. The fallback can only push
to packages *linked* to this repository; a package first pushed from a
workstation is linked to nothing and fails with
`403 permission_denied: write_package`. Public visibility does not help — that
grants anonymous read, not write. See
[.github/CI-CD-PIPELINE.md](.github/CI-CD-PIPELINE.md#ghcr_token-optional-but-needed-for-most-packages).

## Module Version Management

- Version is stored in each module's `kcl.mod` file
- The `push-module` task auto-updates `kcl.mod` before pushing
- Registry tags are bare semver, no `v` prefix (`harvester-vm` publishes `0.2.0`, `0.3.0`)
- Published tags are **immutable** — never republish an existing version; CI skips
  it and `task push-module` refuses it. Ship fixes as a new version instead

### Pinning a module version

A `:version` suffix in the URL path is **not** a pin. It is parsed as part of
the repository name, the tag stays empty, and the reference resolves to the
latest published version -- `kcl` even says so out loud
(`the latest version '0.3.0' will be downloaded`) while the command still looks
pinned.

Which form actually pins depends on the command, so they are not
interchangeable (measured on kcl 0.12.4 against `harvester-vm`, which has
`0.2.0` and `0.3.0` published):

| form | `kcl run` | `kcl mod pull` |
|---|---|---|
| `<module>:0.2.0` | ❌ floats to 0.3.0 | ❌ floats to 0.3.0 |
| `<module>?tag=0.2.0` | ✅ pins | ❌ floats to 0.3.0 |
| `<module> --tag 0.2.0` | ✅ pins | ✅ pins |

`--tag` is the one form that pins everywhere, so prefer it on the command line:

```bash
kcl mod pull oci://ghcr.io/stuttgart-things/<module> --tag 0.2.0   # ✅
kcl mod pull oci://ghcr.io/stuttgart-things/<module>?tag=0.2.0     # ❌ floats
kcl mod pull oci://ghcr.io/stuttgart-things/<module>:0.2.0         # ❌ floats
```

In a `function-kcl` composition step and in `kcl.mod` dependencies:

```yaml
source: oci://ghcr.io/stuttgart-things/<module>?tag=0.2.0
```

```toml
<module> = { oci = "oci://ghcr.io/stuttgart-things/<module>", tag = "0.2.0", version = "0.2.0" }
```

## Claims CLI

Templates in `flux/claim-flux-kustomizations/templates/` define ClaimTemplate YAML specs. The `claims` CLI renders them via the claim-machinery API.

**Render example (non-interactive):**
```bash
CLAIM_API_URL=http://localhost:8080 claims render --non-interactive \
  -t <template-name> \
  -p key=value \
  --skip-secrets \
  --dry-run
```

Key flags: `-t` (template name), `-p` (param, repeatable), `--skip-secrets`, `--dry-run`, `-o` (output dir).
