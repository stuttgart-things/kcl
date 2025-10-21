# xplane-vault-auth

A KCL module for Vault Kubernetes authentication using Terraform provider through Crossplane.

## Features

- **Service Account Creation**: Automatically creates Kubernetes ServiceAccounts for Vault authentication
- **RBAC Configuration**: Sets up proper ClusterRoleBindings for token review permissions
- **Terraform Integration**: Uses Crossplane Terraform provider with inline HCL
- **Multiple Auth Methods**: Supports simple and advanced authentication configurations
- **Flexible Configuration**: Customizable namespaces, roles, and Vault settings

## Quick Start

### Simple Authentication Setup

```kcl
import xplane_vault_auth as vault

# Create basic Vault K8s authentication
auth = vault.simpleVaultK8sAuth(
    name = "my-app"
    clusterName = "production"
    vaultAddr = "https://vault.example.com"
)
```

### Advanced Configuration

```kcl
import xplane_vault_auth as vault

# Advanced setup with custom configuration
auth = vault.vaultK8sAuth(vault.K8sAuth {
    name = "my-service"
    namespace = "production"
    clusterName = "prod-cluster"
    clusterRole = "system:auth-delegator"
    vaultAddr = "https://vault.company.com"
    vaultNamespace = "prod"
    authPath = "kubernetes-prod"
    labels = {
        "app" = "my-service"
        "environment" = "production"
    }
})
```

## Schema Reference

### K8sAuth

Configuration schema for Kubernetes authentication:

```kcl
schema K8sAuth:
    name: str                           # Name prefix for resources
    namespace?: str = "default"         # Kubernetes namespace
    clusterName: str                    # Cluster identifier
    clusterRole?: str = "system:auth-delegator"  # RBAC role
    vaultAddr: str                      # Vault server URL
    vaultNamespace?: str = "default"    # Vault namespace
    authPath?: str = "kubernetes"       # Vault auth path
    tokenReviewerJwt?: str             # Custom JWT token
    kubernetesCaCert?: str             # Custom CA certificate
    labels?: {str: str}                # Resource labels
    annotations?: {str: str}           # Resource annotations
```

## Functions

### vaultK8sAuth

Main function for creating Vault Kubernetes authentication:

```kcl
vaultK8sAuth(auth: K8sAuth) -> [TerraformWorkspace]
```

### simpleVaultK8sAuth

Simplified authentication setup:

```kcl
simpleVaultK8sAuth(name: str, clusterName: str, vaultAddr: str) -> [TerraformWorkspace]
```

### advancedVaultK8sAuth

Advanced setup with custom Terraform code:

```kcl
advancedVaultK8sAuth(auth: K8sAuth, customTerraformCode?: str) -> [TerraformWorkspace]
```

## Generated Resources

The module creates Terraform resources for:

1. **ServiceAccount**: For Vault authentication
2. **ClusterRoleBinding**: Grants token review permissions
3. **Secret**: ServiceAccount token for older Kubernetes versions
4. **Outputs**: JWT token, CA certificate, and metadata

## Prerequisites

- Crossplane with Terraform provider
- Kubernetes cluster with RBAC enabled
- Vault server with Kubernetes authentication enabled

## Examples

See the `examples/` directory for complete usage examples:

- `simple-auth.k`: Basic authentication setup
- Advanced configurations with custom namespaces and labels

## Testing

Run the test suite:

```bash
kcl run tests/test_main.k
```

## Stuttgart-Things Standards

This module follows Stuttgart-Things development standards:

- ✅ KCL best practices
- ✅ Comprehensive documentation
- ✅ Test coverage
- ✅ Example configurations
- ✅ Container-use integration

## Dependencies

Currently uses temporary inline schemas. Will migrate to:
- `crossplane-provider-terraform` (pending OCI publication)

## License

MIT License - see LICENSE file for details.