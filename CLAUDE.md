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

## Module Version Management

- Version is stored in each module's `kcl.mod` file
- The `push-module` task auto-updates `kcl.mod` before pushing
- Registry tags use unversioned semver (no `v` prefix in `kcl.mod`, `v` prefix on OCI tags)

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
