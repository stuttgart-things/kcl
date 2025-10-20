# XPlane Vault Config - Helm Releases

KCL module for deploying Vault-related Helm releases using Crossplane Helm Provider.

## Features

- **Crossplane-compliant variable access pattern** (following Container-Use specs)
- **Secrets Store CSI Driver** deployment via Helm
- **Vault Secrets Operator (VSO)** deployment via Helm
- **Conditional deployment** based on enabled flags
- **Configurable namespaces** and settings

## Deployed Components

### 1. Secrets Store CSI Driver
**Purpose:** Enables Kubernetes secrets to be mounted as volumes from external secret stores like Vault.

- **Chart:** `secrets-store-csi-driver` v1.4.0
- **Repository:** `https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts`
- **Default Namespace:** `secrets-store-csi`
- **Features:** Secret rotation, Linux support

### 2. Vault Secrets Operator (VSO)
**Purpose:** Manages Vault secrets and authentication for Kubernetes workloads.

- **Chart:** `vault-secrets-operator` v0.10.0
- **Repository:** `https://helm.releases.hashicorp.com`
- **Default Namespace:** `vault-secrets-operator`
- **Features:** Direct encrypted cache, default Vault connection

## Usage

### Basic Usage with Defaults

```bash
kcl run main.k -D params='{}'
```

### Production Configuration

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-prod-config",
      "namespaceCsi": "secrets-store-csi",
      "namespaceVso": "vault-secrets-operator",
      "csiEnabled": true,
      "vsoEnabled": true,
      "vsoAtomic": true,
      "vsoWait": true
    }
  }
}'
```

### Disable CSI Driver (VSO Only)

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-vso-only",
      "csiEnabled": false,
      "vsoEnabled": true
    }
  }
}'
```

### Disable VSO (CSI Only)

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-csi-only",
      "csiEnabled": true,
      "vsoEnabled": false
    }
  }
}'
```

## Variable Configuration

### Crossplane XR Specification

All variables follow the Container-Use pattern with safe navigation:

```kcl
name = option("params")?.oxr?.spec?.name or "vault-config"
csi_enabled = option("params")?.oxr?.spec?.csiEnabled or True
```

### Complete Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `name` | "vault-config" | Base name for all resources |
| `namespaceCsi` | "secrets-store-csi" | CSI driver namespace |
| `namespaceVso` | "vault-secrets-operator" | VSO namespace |
| `csiEnabled` | `true` | Deploy Secrets Store CSI Driver |
| `vsoEnabled` | `true` | Deploy Vault Secrets Operator |
| `vsoAtomic` | `true` | VSO atomic deployment |
| `vsoWait` | `true` | Wait for VSO readiness |

## Generated Resources

### When Both Enabled (Default)
1. **secrets-store-csi-driver Release**: CSI driver for secret mounting
2. **vault-secrets-operator Release**: VSO for Vault integration

### Conditional Generation
- Resources are only created when their respective `*_enabled` flag is `true`
- Empty manifests array when both disabled
- Flexible deployment based on requirements

## Terraform Equivalent

This KCL module replaces the following Terraform configuration:

```tf
// DEPLOY VAULT SECRETS STORE CSI DRIVER
resource "helm_release" "csi" {
  count            = var.csi_enabled ? 1 : 0
  name             = "secrets-store-csi-driver"
  namespace        = var.namespace_csi
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart            = "secrets-store-csi-driver"
  version          = "1.4.0"
  atomic           = true
  timeout          = 240
}

// DEPLOY VAULT SECRETS OPERATOR
resource "helm_release" "vso" {
  count            = var.vso_enabled ? 1 : 0
  name             = "vault-secrets-operator"
  namespace        = var.namespace_vso
  create_namespace = true
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  version          = "0.10.0"
  atomic           = var.vso_atomic
  timeout          = 240
  wait             = var.vso_wait
}
```

## Dependencies

- Crossplane Helm Provider
- Kubernetes cluster with Crossplane installed
- Appropriate RBAC permissions for Helm operations

## Development

Built following Container-Use specifications with Crossplane-compliant variable patterns.

**Container-Use Commands:**
- `container-use checkout devoted-poodle`
- `container-use log devoted-poodle`
