# XPlane Vault Config - Helm Releases

KCL module for deploying Vault-related Helm releases using Crossplane Helm Provider.

## Features

- **Crossplane-compliant variable access pattern** (following Container-Use specs)
- **Automatic namespace creation** for all services and auth configurations
- **Secrets Store CSI Driver** deployment via Helm
- **Vault Secrets Operator (VSO)** deployment via Helm
- **External Secrets Operator (ESO)** deployment via Helm
- **Kubernetes ServiceAccount auth setup** with token extraction
- **Token readers** that extract ServiceAccount tokens to connection secrets
- **Conditional deployment** based on enabled flags
- **Crossplane composition resource names** for all resources
- **Configurable namespaces** and chart versions

## Deployed Components

### 1. Secrets Store CSI Driver
**Purpose:** Enables Kubernetes secrets to be mounted as volumes from external secret stores like Vault.

- **Chart:** `secrets-store-csi-driver` v1.5.4 (configurable)
- **Repository:** `https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts`
- **Default Namespace:** `secrets-store-csi`
- **Features:** Secret rotation, Linux support

### 2. Vault Secrets Operator (VSO)
**Purpose:** Manages Vault secrets and authentication for Kubernetes workloads.

- **Chart:** `vault-secrets-operator` v1.0.1 (configurable)
- **Repository:** `https://helm.releases.hashicorp.com`
- **Default Namespace:** `vault-secrets-operator`
- **Features:** Direct encrypted cache, default Vault connection

### 3. External Secrets Operator (ESO)
**Purpose:** Manages secrets from external systems like Vault, AWS Secrets Manager, etc.

- **Chart:** `external-secrets` v0.20.3 (configurable)
- **Repository:** `https://charts.external-secrets.io`
- **Default Namespace:** `external-secrets`
- **Features:** CRD installation, service monitoring, multi-provider support## Usage

### Basic Usage with Defaults

```bash
kcl run main.k -D params='{}'
```

### Basic Usage with Defaults + Apply to cluster

```bash
kcl run --quiet main.k -D params='{"oxr": {"spec": {"clusterName": "vlcuster-k3s-tink1"}}}' --format yaml \
  | yq eval -P '.items[]' - \
  | awk 'BEGIN{doc""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}' \
  | kubectl apply -f -
```

### Basic Usage with Two Auth Configurations + Apply to cluster

```bash
kcl run --quiet main.k -D params='{"oxr": {"spec": {"clusterName": "vlcuster-k3s-tink1", "k8sAuths": [{"name": "vault-auth-prod", "namespace": "production"}, {"name": "vault-auth-dev", "namespace": "development"}]}}}' --format yaml \
  | yq eval -P '.items[]' - \
  | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}' \
  | kubectl apply -f -
```

### Production Configuration

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-prod-config",
      "namespaceCsi": "secrets-store-csi",
      "namespaceVso": "vault-secrets-operator",
      "clusterName": "prod-cluster",
      "csiEnabled": true,
      "vsoEnabled": true
    }
  }
}'
```

### Custom Chart Versions

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-custom-versions",
      "csiChartVersion": "1.6.0",
      "vsoChartVersion": "1.1.0",
      "clusterName": "staging"
    }
  }
}'
```### Disable CSI Driver (VSO Only)

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

### Disable VSO (CSI + ESO Only)

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-csi-eso",
      "csiEnabled": true,
      "vsoEnabled": false,
      "esoEnabled": true
    }
  }
}'
```

### External Secrets Only

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "eso-only",
      "clusterName": "in-cluster",
      "csiEnabled": false,
      "vsoEnabled": false,
      "esoEnabled": true
    }
  }
}'
```

### Custom Kubernetes Auth Configuration

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "multi-auth",
      "k8sAuths": [
        {"name": "vault-auth-prod", "namespace": "production"},
        {"name": "vault-auth-staging", "namespace": "staging"},
        {"name": "vault-auth-dev", "namespace": "development"}
      ]
    }
  }
}'
```

### Only Kubernetes Auth Resources (No Helm Releases)

#### Single ServiceAccount Setup
```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-auth-only",
      "csiEnabled": false,
      "vsoEnabled": false,
      "esoEnabled": false,
      "k8sAuths": [
        {"name": "vault-k8s-auth", "namespace": "vault-system"}
      ]
    }
  }
}'
```

#### Multiple ServiceAccounts Setup
```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "auth-only",
      "csiEnabled": false,
      "vsoEnabled": false,
      "esoEnabled": false,
      "k8sAuths": [
        {"name": "vault-k8s-auth", "namespace": "vault-system"},
        {"name": "app-vault-auth", "namespace": "applications"}
      ]
    }
  }
}'
```

These configurations will generate **only Kubernetes auth resources**:
- ServiceAccounts with `automountServiceAccountToken: true`
- Secrets (service account tokens) with proper annotations
- ClusterRoleBindings to `system:auth-delegator` role
- Token Readers that extract tokens to connection secrets
- **No Helm releases deployed**## Variable Configuration

### Crossplane XR Specification

All variables follow the Container-Use pattern with safe navigation:

```kcl
configName = option("params")?.oxr?.spec?.name or "vault-config"
csiEnabled = option("params")?.oxr?.spec?.csiEnabled or True
```

### Complete Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `name` | "vault-config" | Base name for all resources |
| `namespaceCsi` | "secrets-store-csi" | CSI driver namespace |
| `namespaceVso` | "vault-secrets-operator" | VSO namespace |
| `namespaceEso` | "external-secrets" | ESO namespace |
| `clusterName` | "default" | Crossplane provider config name |
| `csiChartVersion` | "1.5.4" | Secrets Store CSI Driver chart version |
| `vsoChartVersion` | "1.0.1" | Vault Secrets Operator chart version |
| `esoChartVersion` | "0.20.3" | External Secrets Operator chart version |
| `csiEnabled` | `true` | Deploy Secrets Store CSI Driver |
| `vsoEnabled` | `true` | Deploy Vault Secrets Operator |
| `esoEnabled` | `true` | Deploy External Secrets Operator |
| `k8sAuths` | `[{"name": "vault-auth-{configName}", "namespace": "default"}]` | Kubernetes auth configurations for ServiceAccounts |

## Generated Resources

### When All Enabled (Default)
1. **Namespaces**: Automatically created for all services and auth configurations
2. **secrets-store-csi-driver Release**: CSI driver for secret mounting
3. **vault-secrets-operator Release**: VSO for Vault integration
4. **external-secrets Release**: ESO for multi-provider secret management

### Service Account Token Access
Each `k8sAuth` configuration creates a **Connection Secret** at:
- **Name**: `vault-token-{auth.name}`
- **Namespace**: `crossplane-system`
- **Contents**:
  - `token`: Base64-encoded ServiceAccount JWT token

**Usage in Terraform/Crossplane:**
```yaml
# Access the extracted token
secretRef:
  namespace: crossplane-system
  name: vault-token-vault-auth-prod
  key: token
```

### Kubernetes Authentication Resources
For each `k8sAuth` configuration, the module generates:
1. **ServiceAccount**: With `automountServiceAccountToken: true`
2. **Secret**: Service account token with proper annotations
3. **ClusterRoleBinding**: Binding to `system:auth-delegator` role
4. **Token Reader**: Observes the secret and extracts token to connection secret

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
  version          = "1.5.4"
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

## Crossplane Integration

### Composition Resource Names
Every resource includes the `krm.kcl.dev/composition-resource-name` annotation for better Crossplane integration:

- **Namespaces**: `vault-namespace-{namespace-name}`
- **CSI Driver**: `vault-csi-{configName}`
- **VSO**: `vault-vso-{configName}`
- **ESO**: `vault-eso-{configName}`
- **ServiceAccounts**: `vault-serviceaccount-{auth.name}`
- **Secrets**: `vault-secret-{auth.name}`
- **ClusterRoleBindings**: `vault-clusterrolebinding-{auth.name}`
- **Token Readers**: `vault-token-reader-{auth.name}`

### Generated Connection Secrets
Each ServiceAccount auth creates a connection secret in `crossplane-system`:
- **Name**: `vault-token-{auth.name}`
- **Key**: `token` (Base64-encoded JWT)

## Dependencies

- Crossplane Helm Provider v0.1.1+
- Crossplane Kubernetes Provider v0.18.0+
- Kubernetes cluster with Crossplane installed
- Appropriate RBAC permissions for Helm operations

## Development

Built following Container-Use specifications with Crossplane-compliant variable patterns.

**Container-Use Commands:**
- `container-use checkout devoted-poodle`
- `container-use log devoted-poodle`
