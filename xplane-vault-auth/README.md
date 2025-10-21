# xplane-vault-auth# Vault Authentication KCL Module



A KCL module for creating HashiCorp Vault Kubernetes authentication backends using Crossplane and the Terraform provider.This KCL module provides simplified creation of Kubernetes ServiceAccounts for Vault authentication using Terraform inline code via the Crossplane Terraform Provider.



## Overview## 🎯 Features



This module enables you to create Vault Kubernetes authentication backends that allow Kubernetes pods to authenticate with Vault using service account tokens. Unlike traditional approaches that create Kubernetes ServiceAccounts, this module creates the actual Vault authentication backends using the `vault_auth_backend` Terraform resource.- **Terraform Inline Code**: Generates HCL for Kubernetes ServiceAccount creation

- **Multiple ServiceAccounts**: Support for multiple authentication configurations

## Features- **Crossplane Integration**: Uses crossplane-provider-terraform for execution

- **Connection Secrets**: Optional output management through Kubernetes secrets

- ✅ **Vault Auth Backend Creation**: Creates actual Vault Kubernetes authentication backends- **Flexible Configuration**: Simple helpers and advanced configuration options

- ✅ **Multi-Backend Support**: Configure multiple auth backends in a single workspace- **Type Safety**: Full KCL type checking and validation

- ✅ **Flexible Configuration**: Support for custom Vault addresses, TLS settings, and token secrets

- ✅ **Crossplane Integration**: Uses crossplane-provider-terraform for resource management## 📦 Installation

- ✅ **OCI Package**: Available as an OCI artifact for easy consumption

### As OCI Registry Package

## Installation

```bash

```bash# Add to kcl.mod dependencies

# Add the module as a dependencykcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0

kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0```

```

### From Source

## Usage

```bash

### Simple Authentication Backend# Clone the KCL repository

git clone https://github.com/stuttgart-things/kcl.git

```kclcd kcl/xplane-vault-auth

import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0 as vault_auth```



# Create a simple Vault K8s auth backend## 🚀 Usage

authBackend = vault_auth.simpleVaultK8sAuth(

    "my-app",                        # backend name### Quick Start Examples

    "prod-cluster",                  # cluster name

    "https://vault.example.com"      # vault address#### 1. Simple ServiceAccount Creation

)

``````kcl

import xplane_vault_auth as vault_auth

### Multiple Authentication Backends

# Define authentication configurations

```kclauths = [

import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0 as vault_auth    vault_auth.K8sAuth {

        name = "vault-auth-app"

# Configure multiple auth backends        namespace = "production"

multiAuth = vault_auth.multiVaultK8sAuth([    }

    vault_auth.K8sAuth {    vault_auth.K8sAuth {

        name = "web-service"        name = "vault-auth-worker"

        clusterName = "prod"        namespace = "workers"

        vaultAddr = "https://vault.prod.com"        automountServiceAccountToken = False

    }    }

    vault_auth.K8sAuth {]

        name = "api-service"

        clusterName = "prod" # Create simple Terraform workspace

        vaultAddr = "https://vault.prod.com"workspace = vault_auth.simpleVaultAuth(

    }    "vault-authentication",

], "prod", "https://vault.prod.com")    auths

```)

```

### Full Configuration

#### 2. Advanced Configuration with Connection Secrets

```kcl

import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0 as vault_auth```kcl

# Advanced setup with connection secrets

config = vault_auth.VaultConfig {workspace = vault_auth.advancedVaultAuth(

    k8sAuths = [    "vault-auth-advanced",

        vault_auth.K8sAuth {    "vault-system",

            name = "application"    auths,

            clusterName = "prod"    "vault-service-account-outputs"

            vaultAddr = "https://vault.prod.com")

            skipTlsVerify = false```

            vaultTokenSecret = "vault-root-token"

            vaultTokenSecretNamespace = "vault-system"#### 3. Full Configuration Control

        }

    ]```kcl

    clusterName = "prod"config = vault_auth.VaultAuthConfig {

    vaultAddr = "https://vault.prod.com"    workspaceName = "vault-auth-complete"

    skipTlsVerify = false    workspaceNamespace = "infrastructure"

    vaultTokenSecret = "vault-root-token"

    vaultTokenSecretNamespace = "vault-system"    k8sAuths = [

}        vault_auth.K8sAuth {

            name = "vault-auth-frontend"

authBackends = vault_auth.vaultK8sAuth(config)            namespace = "frontend-prod"

```        }

        vault_auth.K8sAuth {

## Schema Reference            name = "vault-auth-backend"

            namespace = "backend-prod"

### VaultConfig            automountServiceAccountToken = True

        }

| Field | Type | Description | Default |    ]

|-------|------|-------------|---------|

| `k8sAuths` | `[K8sAuth]` | List of Kubernetes auth configurations | Required |    providerConfigRef = "terraform-k8s-provider"

| `clusterName` | `str` | Kubernetes cluster name | Required |    connectionSecret = vault_auth.terraform.TerraformConnectionSecret {

| `vaultAddr` | `str` | Vault server address | Required |        name = "vault-auth-results"

| `skipTlsVerify` | `bool` | Skip TLS verification | `false` |        namespace = "infrastructure"

| `vaultTokenSecret` | `str` | Secret containing Vault token | `"vault-token"` |    }

| `vaultTokenSecretNamespace` | `str` | Namespace of token secret | `"vault-system"` |

    managementPolicies = ["Create", "Update", "Delete"]

### K8sAuth    deletionPolicy = "Delete"

}

| Field | Type | Description | Default |

|-------|------|-------------|---------|workspace = vault_auth.generateVaultAuthWorkspace(config)

| `name` | `str` | Authentication backend name | Required |```

| `clusterName` | `str` | Kubernetes cluster name | Required |

| `vaultAddr` | `str` | Vault server address | Required |## 📚 Generated Terraform Code

| `skipTlsVerify` | `bool` | Skip TLS verification | `false` |

| `vaultTokenSecret` | `str` | Secret containing Vault token | `"vault-token"` |The module generates the following Terraform HCL code:

| `vaultTokenSecretNamespace` | `str` | Namespace of token secret | `"vault-system"` |

```hcl

## Functionsvariable "k8s_auths" {

  description = "List of Kubernetes authentications to create"

### `vaultK8sAuth(config: VaultConfig) -> [Workspace]`  type = list(object({

    name      = string

Creates Vault Kubernetes authentication backends based on the provided configuration.    namespace = string

    automountServiceAccountToken = optional(bool, true)

### `simpleVaultK8sAuth(name: str, clusterName: str, vaultAddr: str) -> [Workspace]`  }))

  default = []

Convenience function to create a single authentication backend with minimal configuration.}



### `multiVaultK8sAuth(auths: [K8sAuth], clusterName: str, vaultAddr: str) -> [Workspace]`resource "kubernetes_manifest" "service_account" {

  for_each = {

Creates multiple authentication backends with shared cluster and Vault settings.    for auth in var.k8s_auths :

    auth.name => auth

## Generated Resources  }



This module creates Crossplane `Workspace` resources that contain Terraform configurations for:  manifest = {

    "apiVersion" = "v1"

- **Vault Provider**: Configured with authentication token from Kubernetes secret    "kind"       = "ServiceAccount"

- **Vault Auth Backends**: Kubernetes authentication backends with unique paths    "metadata" = {

- **Variables**: Parameterized configuration for flexibility      "name"      = each.value["name"]

- **Outputs**: Information about created auth backends      "namespace" = each.value["namespace"]

    }

## Prerequisites    "automountServiceAccountToken" = each.value["automountServiceAccountToken"]

  }

- Crossplane installed in your cluster}

- crossplane-provider-terraform configured

- Vault server accessible from the clusteroutput "service_accounts" {

- Vault authentication token stored in a Kubernetes secret  description = "Created ServiceAccounts"

  value = {

## Example Terraform Output    for k, v in kubernetes_manifest.service_account : k => {

      name      = v.manifest.metadata.name

The module generates Terraform configurations like:      namespace = v.manifest.metadata.namespace

    }

```hcl  }

provider "vault" {}

  address         = var.vault_addr

  skip_tls_verify = var.skip_tls_verifyoutput "service_account_names" {

  token           = var.vault_token  description = "List of created ServiceAccount names"

}  value = [for sa in kubernetes_manifest.service_account : sa.manifest.metadata.name]

}

resource "vault_auth_backend" "kubernetes" {```

  for_each = {

    for auth in var.k8s_auths :## 🔧 API Reference

    auth.name => auth

  }### Core Schemas



  type = "kubernetes"#### `K8sAuth`

  path = "${var.cluster_name}-${each.value["name"]}"Configuration for a single Kubernetes ServiceAccount.

}

```| Field | Type | Required | Default | Description |

|-------|------|----------|---------|-------------|

## Repository Structure| `name` | string | ✅ | - | ServiceAccount name |

| `namespace` | string | ✅ | - | Kubernetes namespace |

```| `automountServiceAccountToken` | bool | ❌ | `true` | Whether to automount service account token |

.

├── README.md#### `VaultAuthConfig`

├── kcl.modComplete configuration for Vault authentication workspace.

├── main.k                    # Core module logic

├── examples/| Field | Type | Required | Default | Description |

│   └── vault-k8s-auth.k     # Usage examples|-------|------|----------|---------|-------------|

└── tests/| `workspaceName` | string | ✅ | - | Terraform workspace name |

    └── test_main.k          # Test suite| `workspaceNamespace` | string | ❌ | `"vault-system"` | Kubernetes namespace for workspace |

```| `k8sAuths` | [K8sAuth] | ✅ | - | List of ServiceAccount configurations |

| `providerConfigRef` | string | ❌ | `"default"` | Terraform provider config reference |

## Contributing| `connectionSecret` | TerraformConnectionSecret | ❌ | - | Connection secret for outputs |

| `managementPolicies` | [str] | ❌ | `["*"]` | Crossplane management policies |

This module follows Stuttgart-Things standards:| `deletionPolicy` | string | ❌ | `"Delete"` | Resource deletion policy |



1. Use semantic versioning for releases### Helper Functions

2. Add tests for new functionality

3. Update documentation for API changes#### `simpleVaultAuth(workspaceName, auths)`

4. Follow KCL best practicesCreates a basic Terraform workspace for ServiceAccount creation.



## License**Parameters:**

- `workspaceName` (string): Name of the Terraform workspace

Apache License 2.0 - see LICENSE file for details.- `auths` ([K8sAuth]): List of ServiceAccount configurations

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