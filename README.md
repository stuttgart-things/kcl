# stuttgart-things/kcl: KCL Modules & Structure

This repository contains KCL modules, tests, and documentation for Crossplane, Kubernetes, Flux, Helm, and related technologies. All modules are published as OCI artifacts and follow team standards for development, testing, and release.

## Folder Overview

### 1. `models/`
- **Purpose:** KCL modules for Crossplane, Kubernetes, Flux, Helm, etc.
- **Contents:**
  - KCL model files and reusable logic

### 2. `tests/`
- **Purpose:** Technology-specific tests, wrappers, Makefiles, and documentation
- **Contents:**
  - `tekton/` — Tekton module tests and usage examples
  - `argo/` — Argo module tests (if present)
  - Add more technology folders as needed

### 3. `crossplane/`, `flux/`
- **Purpose:** Technology-specific KCL logic and integrations
- **Contents:**
  - Crossplane and Flux KCL modules, helpers, and configs

### 4. `README.md`, `Taskfile.yaml`, `.container-use/`, `.github/`
- **Purpose:** Documentation, automation, and team standards
- **Contents:**
  - Main README, automation scripts, decision docs, CI/CD config

---

## Module Overview

### Crossplane Modules

| Module                  | Path                                             | Description                                      |
|-------------------------|--------------------------------------------------|--------------------------------------------------|
| xplane-cilium           | crossplane/xplane-cilium/                        | Cilium CNI, L2 announcements, advanced networking|
| xplane-helm-release     | crossplane/xplane-helm-release/                  | Helm chart deployment via Crossplane              |
| xplane-vault-auth       | crossplane/xplane-vault-auth/                    | Vault Kubernetes authentication via Terraform     |
| xplane-vault-config     | crossplane/xplane-vault-config/                  | Vault, CSI, ESO, RBAC, ServiceAccount tokens      |
| xplane-vcluster         | crossplane/xplane-vcluster/                      | VCluster deployment with connection secrets       |

### Flux Modules

| Module                        | Path                                             | Description                                      |
|-------------------------------|--------------------------------------------------|--------------------------------------------------|
| flux-kustomization-tekton     | flux/flux-kustomization-tekton/                  | Tekton deployment via Flux Kustomization          |
| flux-operator-instance        | flux/flux-operator-instance/                     | FluxInstance CRD, Git/SOPS secrets, tuning        |

### Models

| Module                        | Path                                             | Description                                      |
|-------------------------------|--------------------------------------------------|--------------------------------------------------|
| crossplane-provider-helm      | models/crossplane-provider-helm/                 | Helm releases via Crossplane                      |
| crossplane-provider-terraform | models/crossplane-provider-terraform/            | Terraform workspaces via Crossplane               |
| flux-helmrelease              | models/flux-helmrelease/                         | Flux HelmRelease CRDs and helpers                 |
| flux-kustomization            | models/flux-kustomization/                       | Flux Kustomization CRDs and helpers               |

- All modules are published as OCI artifacts (see each folder's `kcl.mod` for registry info).
- Usage examples and API docs are in each module's `README.md` and `examples/`.

---

## Installation

```bash
# Add a module (example)
kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-config
```

All modules are available as OCI artifacts and can be added directly via `kcl mod add ...`.

---

## Example: Tekton Kustomization

See `tests/tekton/test_module_tekton.k` for usage:

```kcl
import kcl_flux_tekton as tekton
tekton_config = tekton.items({
    name = "tekton"
    namespace = "flux-system"
    path = "./cicd/tekton"
    sourceKind = "GitRepository"
    sourceName = "flux-apps"
    interval = "1h"
    timeout = "35m"
    postBuild = {
        substitute = {
            TEKTON_NAMESPACE = "tekton-pipelines"
            TEKTON_VERSION = "0.77.0"
        }
    }
})
```

---

## Development & Workflow

1. Develop according to team standards (`.container-use/decisions.md`)
2. Syntax and resource tests (`kcl run ...`)
3. Versioning and commit conventions
4. Release as OCI artifact (`kcl mod push ...`)

---

## Standards & Support

- All development guidelines: `.container-use/decisions.md`
- Automated checks & pre-commit hooks
- OCI registry for all modules

For questions, feature requests, or contributions: please open an issue or pull request in the [GitHub Repo](https://github.com/stuttgart-things/kcl).

---

**To view changes or use this structure in your environment:**
- Use `container-use log <env_id>` to see the change history.
- Use `container-use checkout <env_id>` to access the updated environment.

---
