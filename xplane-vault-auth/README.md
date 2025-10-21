# Vault Authentication KCL Module

This KCL module provides simplified creation of Kubernetes ServiceAccounts for Vault authentication using Terraform inline code via the Crossplane Terraform Provider.

## 🎯 Features

- **Terraform Inline Code**: Generates HCL for Kubernetes ServiceAccount creation
- **Multiple ServiceAccounts**: Support for multiple authentication configurations
- **Crossplane Integration**: Uses crossplane-provider-terraform for execution
- **Connection Secrets**: Optional output management through Kubernetes secrets
- **Flexible Configuration**: Simple helpers and advanced configuration options
- **Type Safety**: Full KCL type checking and validation

## 📦 Installation

### As OCI Registry Package

```bash
# Add to kcl.mod dependencies
kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0
```

### From Source

```bash
# Clone the KCL repository  
git clone https://github.com/stuttgart-things/kcl.git
cd kcl/xplane-vault-auth
```

## 🚀 Usage

### Quick Start Examples

#### 1. Simple ServiceAccount Creation

```kcl
import xplane_vault_auth as vault_auth

# Define authentication configurations
auths = [
    vault_auth.K8sAuth {
        name = "vault-auth-app"
        namespace = "production"
    }
    vault_auth.K8sAuth {
        name = "vault-auth-worker"
        namespace = "workers"
        automountServiceAccountToken = False
    }
]

# Create simple Terraform workspace
workspace = vault_auth.simpleVaultAuth(
    "vault-authentication",
    auths
)
```

#### 2. Advanced Configuration with Connection Secrets

```kcl
# Advanced setup with connection secrets
workspace = vault_auth.advancedVaultAuth(
    "vault-auth-advanced",
    "vault-system",
    auths,
    "vault-service-account-outputs"
)
```

#### 3. Full Configuration Control

```kcl
config = vault_auth.VaultAuthConfig {
    workspaceName = "vault-auth-complete"
    workspaceNamespace = "infrastructure"
    
    k8sAuths = [
        vault_auth.K8sAuth {
            name = "vault-auth-frontend"
            namespace = "frontend-prod"
        }
        vault_auth.K8sAuth {
            name = "vault-auth-backend"
            namespace = "backend-prod"
            automountServiceAccountToken = True
        }
    ]
    
    providerConfigRef = "terraform-k8s-provider"
    connectionSecret = vault_auth.terraform.TerraformConnectionSecret {
        name = "vault-auth-results"
        namespace = "infrastructure"
    }
    
    managementPolicies = ["Create", "Update", "Delete"]
    deletionPolicy = "Delete"
}

workspace = vault_auth.generateVaultAuthWorkspace(config)
```

## 📚 Generated Terraform Code

The module generates the following Terraform HCL code:

```hcl
variable "k8s_auths" {
  description = "List of Kubernetes authentications to create"
  type = list(object({
    name      = string
    namespace = string
    automountServiceAccountToken = optional(bool, true)
  }))
  default = []
}

resource "kubernetes_manifest" "service_account" {
  for_each = {
    for auth in var.k8s_auths :
    auth.name => auth
  }

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = each.value["name"]
      "namespace" = each.value["namespace"]
    }
    "automountServiceAccountToken" = each.value["automountServiceAccountToken"]
  }
}

output "service_accounts" {
  description = "Created ServiceAccounts"
  value = {
    for k, v in kubernetes_manifest.service_account : k => {
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }
  }
}

output "service_account_names" {
  description = "List of created ServiceAccount names"
  value = [for sa in kubernetes_manifest.service_account : sa.manifest.metadata.name]
}
```

## 🔧 API Reference

### Core Schemas

#### `K8sAuth`
Configuration for a single Kubernetes ServiceAccount.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | ✅ | - | ServiceAccount name |
| `namespace` | string | ✅ | - | Kubernetes namespace |
| `automountServiceAccountToken` | bool | ❌ | `true` | Whether to automount service account token |

#### `VaultAuthConfig`
Complete configuration for Vault authentication workspace.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `workspaceName` | string | ✅ | - | Terraform workspace name |
| `workspaceNamespace` | string | ❌ | `"vault-system"` | Kubernetes namespace for workspace |
| `k8sAuths` | [K8sAuth] | ✅ | - | List of ServiceAccount configurations |
| `providerConfigRef` | string | ❌ | `"default"` | Terraform provider config reference |
| `connectionSecret` | TerraformConnectionSecret | ❌ | - | Connection secret for outputs |
| `managementPolicies` | [str] | ❌ | `["*"]` | Crossplane management policies |
| `deletionPolicy` | string | ❌ | `"Delete"` | Resource deletion policy |

### Helper Functions

#### `simpleVaultAuth(workspaceName, auths)`
Creates a basic Terraform workspace for ServiceAccount creation.

**Parameters:**
- `workspaceName` (string): Name of the Terraform workspace
- `auths` ([K8sAuth]): List of ServiceAccount configurations

#### `advancedVaultAuth(workspaceName, namespace, auths, secretName)`
Creates an advanced workspace with connection secrets.

**Parameters:**
- `workspaceName` (string): Name of the Terraform workspace
- `namespace` (string): Kubernetes namespace for workspace
- `auths` ([K8sAuth]): List of ServiceAccount configurations
- `secretName` (string): Name for connection secret

#### `generateVaultAuthWorkspace(config)`
Creates a workspace from complete configuration.

**Parameters:**
- `config` (VaultAuthConfig): Complete workspace configuration

## 🔧 Development

### Running Tests

```bash
cd xplane-vault-auth
kcl run tests/test_main.k
```

### Running Examples

```bash
kcl run examples/simple-auth.k
```

### Validating Generated Resources

```bash
# Test resource generation and validation
kcl run examples/simple-auth.k | kubectl apply --dry-run=client -f -
```

## 🏗️ Integration

### With Crossplane Compositions

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: vault-auth-composition
spec:
  compositeTypeRef:
    apiVersion: vault.platform.io/v1alpha1
    kind: XVaultAuth
  functions:
  - name: kcl-function
    type: function
    step: normal
    input:
      apiVersion: krm.kcl.dev/v1alpha1
      kind: KCLRun
      spec:
        source: |
          import xplane_vault_auth as vault_auth
          
          auths = [
              vault_auth.K8sAuth {
                  name = option("oxr").spec.name + "-auth"
                  namespace = option("oxr").spec.namespace
              }
          ]
          
          workspaces = vault_auth.simpleVaultAuth(
              option("oxr").spec.workspaceName,
              auths
          )
```

### Multi-Environment Setup

```kcl
import xplane_vault_auth as vault_auth

environments = ["dev", "staging", "prod"]

# Create authentication for each environment
auth_workspaces = [
    vault_auth.advancedVaultAuth(
        "vault-auth-{}".format(env),
        "vault-{}".format(env),
        [
            vault_auth.K8sAuth {
                name = "vault-auth-app"
                namespace = "{}-applications".format(env)
            }
            vault_auth.K8sAuth {
                name = "vault-auth-data"
                namespace = "{}-data".format(env)
            }
        ],
        "vault-auth-outputs-{}".format(env)
    ) for env in environments
]
```

## 🔄 Terraform Provider Requirements

This module requires the Kubernetes Terraform provider to be configured in your Crossplane environment:

```yaml
apiVersion: tf.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: terraform-k8s-provider
spec:
  configuration: |
    terraform {
      required_providers {
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 2.20"
        }
      }
    }
    
    provider "kubernetes" {
      # Configuration from environment or service account
    }
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite: `kcl run tests/test_main.k`
6. Submit a pull request

## 📝 License

This project is licensed under the Apache License 2.0. See [LICENSE](../LICENSE) for details.

## 🔗 Related Projects

- [crossplane-provider-terraform](../crossplane-provider-terraform/) - Base Terraform provider module
- [xplane-vault-config](../xplane-vault-config/) - Complete Vault services configuration
- [Crossplane Terraform Provider](https://github.com/crossplane-contrib/provider-terraform) - Upstream provider
- [Stuttgart-Things Infrastructure](https://github.com/stuttgart-things) - Platform engineering resources

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/stuttgart-things/kcl/issues)
- **Documentation**: [Stuttgart-Things Docs](https://stuttgart-things.github.io)
- **Community**: [Stuttgart-Things Discussions](https://github.com/orgs/stuttgart-things/discussions)