

# stuttgart-things/kcl

**KCL module collection for Crossplane and Kubernetes**

This repository provides reusable KCL modules for automated generation of Kubernetes resources for infrastructure and applications. All modules are published as OCI artifacts and follow team standards for development, testing, and release.


## Module Overview

| Module                   | OCI Registry                                         | Description                       |
|-------------------------|------------------------------------------------------|-----------------------------------|
| xplane-vault-config     | oci://ghcr.io/stuttgart-things/xplane-vault-config   | Vault, CSI, ESO, RBAC             |
| xplane-vcluster         | oci://ghcr.io/stuttgart-things/xplane-vcluster       | VCluster with secret management   |
| xplane-cilium           | oci://ghcr.io/stuttgart-things/xplane-cilium         | Cilium CNI, L2 announcements      |
| xplane-helm-release     | oci://ghcr.io/stuttgart-things/xplane-helm-release   | Helm chart deployment             |
| crossplane-provider-helm| oci://ghcr.io/stuttgart-things/crossplane-provider-helm | Helm provider models           |
| kcl-flux-tekton         | oci://ghcr.io/stuttgart-things/kcl-flux-tekton       | Tekton via Flux/K8s abstractions  |

---

## Installation

```bash
# Add a module (example)
kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-config
```

All modules are available as OCI artifacts and can be added directly via `kcl mod add ...`.

---

---

---

---

## Examples

```kcl
# Vault configuration
import xplane_vault_config as vault
vault_config = vault.items({
    clusterName = "my-cluster"
    enableCSI = True
    enableVSO = True
    enableESO = False
})

# VCluster deployment
import xplane_vcluster as vcluster
vcluster_config = vcluster.items({
    name = "dev-cluster"
    version = "0.29.0"
    clusterName = "production"
    targetNamespace = "vcluster-dev"
})

# Cilium CNI
import xplane_cilium as cilium
cilium_config = cilium.items({
    name = "cilium-cni"
    targetNamespace = "kube-system"
    version = "1.19.0"
    clusterName = "k8s-prod"
    routingMode = "native"
})

# Helm chart deployment
import xplane_helm_release as helm
helm_config = helm.items({
    name = "nginx-ingress"
    namespace = "ingress-nginx"
    chart = "ingress-nginx"
    repository = "https://kubernetes.github.io/ingress-nginx"
    version = "4.8.3"
    cluster = "production-cluster"
    values = {
        controller = {
            service = {
                type = "LoadBalancer"
            }
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

Questions, feature requests or contributions: please use the [GitHub repo](https://github.com/stuttgart-things/kcl).
