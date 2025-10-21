# xplane-vault-auth# xplane-vault-auth# xplane-vault-auth# xplane-vault-auth# Vault Authentication KCL Module



A KCL module for creating HashiCorp Vault Kubernetes authentication backends using Crossplane and the Terraform provider.



## OverviewA KCL module for creating HashiCorp Vault Kubernetes authentication backends using Crossplane and the Terraform provider.



This module enables you to create Vault Kubernetes authentication backends that allow Kubernetes pods to authenticate with Vault using service account tokens. Unlike traditional approaches that create Kubernetes ServiceAccounts, this module creates the actual Vault authentication backends using the `vault_auth_backend` Terraform resource.



The implementation uses Terraform's `count` meta-argument for creating multiple auth backends from a simple list, avoiding the complexity of `for_each` with object dictionaries.## OverviewA KCL module for creating HashiCorp Vault Kubernetes authentication backends using Crossplane and the Terraform provider.



## Features



- ✅ **Vault Auth Backend Creation**: Creates actual Vault Kubernetes authentication backendsThis module enables you to create Vault Kubernetes authentication backends that allow Kubernetes pods to authenticate with Vault using service account tokens. Unlike traditional approaches that create Kubernetes ServiceAccounts, this module creates the actual Vault authentication backends using the `vault_auth_backend` Terraform resource.

- ✅ **Multi-Backend Support**: Configure multiple auth backends in a single workspace

- ✅ **Simple List-Based Configuration**: Uses `count` instead of complex `for_each` dictionaries

- ✅ **Flexible Configuration**: Support for custom Vault addresses, TLS settings, and token secrets

- ✅ **Crossplane Integration**: Uses crossplane-provider-terraform for resource management## Features## OverviewA KCL module for creating HashiCorp Vault Kubernetes authentication backends using Crossplane and the Terraform provider.This KCL module provides simplified creation of Kubernetes ServiceAccounts for Vault authentication using Terraform inline code via the Crossplane Terraform Provider.

- ✅ **OCI Package**: Available as an OCI artifact for easy consumption



## Installation

- ✅ **Vault Auth Backend Creation**: Creates actual Vault Kubernetes authentication backends

```bash

# Add the module as a dependency- ✅ **Multi-Backend Support**: Configure multiple auth backends in a single workspace

kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0

```- ✅ **Flexible Configuration**: Support for custom Vault addresses, TLS settings, and token secretsThis module enables you to create Vault Kubernetes authentication backends that allow Kubernetes pods to authenticate with Vault using service account tokens. Unlike traditional approaches that create Kubernetes ServiceAccounts, this module creates the actual Vault authentication backends using the `vault_auth_backend` Terraform resource.



## Usage- ✅ **Crossplane Integration**: Uses crossplane-provider-terraform for resource management



### Simple Authentication Backend- ✅ **OCI Package**: Available as an OCI artifact for easy consumption



```kcl

import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth

## Installation## Features## Overview## 🎯 Features

# Create a simple Vault K8s auth backend

authBackend = vault_auth.simpleVaultK8sAuth(

    "my-app",                        # backend name

    "prod-cluster",                  # cluster name```bash

    "https://vault.example.com"      # vault address

)# Add the module as a dependency

```

kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0- ✅ **Vault Auth Backend Creation**: Creates actual Vault Kubernetes authentication backends

### Multiple Authentication Backends

```

```kcl

import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth- ✅ **Multi-Backend Support**: Configure multiple auth backends in a single workspace



# Configure multiple auth backends## Usage

multiAuth = vault_auth.multiVaultK8sAuth([

    vault_auth.K8sAuth {- ✅ **Flexible Configuration**: Support for custom Vault addresses, TLS settings, and token secretsThis module enables you to create Vault Kubernetes authentication backends that allow Kubernetes pods to authenticate with Vault using service account tokens. Unlike traditional approaches that create Kubernetes ServiceAccounts, this module creates the actual Vault authentication backends using the `vault_auth_backend` Terraform resource.- **Terraform Inline Code**: Generates HCL for Kubernetes ServiceAccount creation

        name = "web-service"

        clusterName = "prod"### Simple Authentication Backend

        vaultAddr = "https://vault.prod.com"

    }- ✅ **Crossplane Integration**: Uses crossplane-provider-terraform for resource management

    vault_auth.K8sAuth {

        name = "api-service"```kcl

        clusterName = "prod" 

        vaultAddr = "https://vault.prod.com"import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth- ✅ **OCI Package**: Available as an OCI artifact for easy consumption- **Multiple ServiceAccounts**: Support for multiple authentication configurations

    }

], "prod", "https://vault.prod.com")

```

# Create a simple Vault K8s auth backend

### Full Configuration

authBackend = vault_auth.simpleVaultK8sAuth(

```kcl

import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth    "my-app",                        # backend name## Installation## Features- **Crossplane Integration**: Uses crossplane-provider-terraform for execution



config = vault_auth.VaultConfig {    "prod-cluster",                  # cluster name

    k8sAuths = [

        vault_auth.K8sAuth {    "https://vault.example.com"      # vault address

            name = "application"

            clusterName = "prod")

            vaultAddr = "https://vault.prod.com"

            skipTlsVerify = False``````bash- **Connection Secrets**: Optional output management through Kubernetes secrets

            vaultTokenSecret = "vault-root-token"

            vaultTokenSecretNamespace = "vault-system"

        }

    ]### Multiple Authentication Backends# Add the module as a dependency

    clusterName = "prod"

    vaultAddr = "https://vault.prod.com"

    skipTlsVerify = False

    vaultTokenSecret = "vault-root-token"```kclkcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0- ✅ **Vault Auth Backend Creation**: Creates actual Vault Kubernetes authentication backends- **Flexible Configuration**: Simple helpers and advanced configuration options

    vaultTokenSecretNamespace = "vault-system"

}import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth



authBackends = vault_auth.vaultK8sAuth(config)```

```

# Configure multiple auth backends

## Example Terraform Output

multiAuth = vault_auth.multiVaultK8sAuth([- ✅ **Multi-Backend Support**: Configure multiple auth backends in a single workspace- **Type Safety**: Full KCL type checking and validation

The module generates Terraform configurations using `count` for simplicity:

    vault_auth.K8sAuth {

```hcl

provider "vault" {        name = "web-service"## Usage

  address         = var.vault_addr

  skip_tls_verify = var.skip_tls_verify        clusterName = "prod"

  token           = var.vault_token

}        vaultAddr = "https://vault.prod.com"- ✅ **Flexible Configuration**: Support for custom Vault addresses, TLS settings, and token secrets



# Using count for multiple auth backends (simpler than for_each)    }

resource "vault_auth_backend" "kubernetes" {

  count = length(var.k8s_auths)    vault_auth.K8sAuth {### Simple Authentication Backend



  type = "kubernetes"        name = "api-service"

  path = "${var.cluster_name}-${var.k8s_auths[count.index].name}"

}        clusterName = "prod" - ✅ **Crossplane Integration**: Uses crossplane-provider-terraform for resource management## 📦 Installation



# Simple list-based variable definition        vaultAddr = "https://vault.prod.com"

variable "k8s_auths" {

  description = "List of Kubernetes auth configurations"    }```kcl

  type = list(object({

    name          = string], "prod", "https://vault.prod.com")

    cluster_name  = string

    vault_addr    = string```import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth- ✅ **OCI Package**: Available as an OCI artifact for easy consumption

    skip_tls_verify = bool

  }))

}

### Full Configuration

# Array-based output structure

output "auth_backends" {

  description = "Created Vault auth backends"

  value = [```kcl# Create a simple Vault K8s auth backend### As OCI Registry Package

    for i in range(length(var.k8s_auths)) :

    {import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth

      path = vault_auth_backend.kubernetes[i].path

      type = vault_auth_backend.kubernetes[i].typeauthBackend = vault_auth.simpleVaultK8sAuth(

      name = var.k8s_auths[i].name

    }config = vault_auth.VaultConfig {

  ]

}    k8sAuths = [    "my-app",                        # backend name## Installation

```

        vault_auth.K8sAuth {

## Advantages of Count-Based Approach

            name = "application"    "prod-cluster",                  # cluster name

### ✅ **Simplicity**

- No complex dictionary transformations required            clusterName = "prod"

- Direct list iteration with `count.index`

- Straightforward variable definitions            vaultAddr = "https://vault.prod.com"    "https://vault.example.com"      # vault address```bash



### ✅ **Performance**            skipTlsVerify = False

- Faster plan/apply cycles for large numbers of backends

- Less memory usage during Terraform execution            vaultTokenSecret = "vault-root-token")

- Simpler state management

            vaultTokenSecretNamespace = "vault-system"

### ✅ **Maintainability**

- Easier to understand for team members        }``````bash# Add to kcl.mod dependencies

- Less prone to iteration errors

- Simpler debugging and troubleshooting    ]



## Development    clusterName = "prod"



### Running Tests    vaultAddr = "https://vault.prod.com"



```bash    skipTlsVerify = False### Multiple Authentication Backends# Add the module as a dependencykcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0

cd xplane-vault-auth

kcl run tests/test_main.k    vaultTokenSecret = "vault-root-token"

```

    vaultTokenSecretNamespace = "vault-system"

### Running Examples

}

```bash

kcl run examples/vault-k8s-auth-corrected.k```kclkcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0```

```

authBackends = vault_auth.vaultK8sAuth(config)

## License

```import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth

Apache License 2.0 - see LICENSE file for details.


## Schema Reference```



### VaultConfig# Configure multiple auth backends



| Field | Type | Description | Default |multiAuth = vault_auth.multiVaultK8sAuth([### From Source

|-------|------|-------------|---------|

| `k8sAuths` | `[K8sAuth]` | List of Kubernetes auth configurations | Required |    vault_auth.K8sAuth {

| `clusterName` | `str` | Kubernetes cluster name | Required |

| `vaultAddr` | `str` | Vault server address | Required |        name = "web-service"## Usage

| `skipTlsVerify` | `bool` | Skip TLS verification | `False` |

| `vaultTokenSecret` | `str` | Secret containing Vault token | `"vault-token"` |        clusterName = "prod"

| `vaultTokenSecretNamespace` | `str` | Namespace of token secret | `"vault-system"` |

        vaultAddr = "https://vault.prod.com"```bash

### K8sAuth

    }

| Field | Type | Description | Default |

|-------|------|-------------|---------|    vault_auth.K8sAuth {### Simple Authentication Backend# Clone the KCL repository

| `name` | `str` | Authentication backend name | Required |

| `clusterName` | `str` | Kubernetes cluster name | Required |        name = "api-service"

| `vaultAddr` | `str` | Vault server address | Required |

| `skipTlsVerify` | `bool` | Skip TLS verification | `False` |        clusterName = "prod" git clone https://github.com/stuttgart-things/kcl.git

| `vaultTokenSecret` | `str` | Secret containing Vault token | `"vault-token"` |

| `vaultTokenSecretNamespace` | `str` | Namespace of token secret | `"vault-system"` |        vaultAddr = "https://vault.prod.com"



## Functions    }```kclcd kcl/xplane-vault-auth



### `vaultK8sAuth(config: VaultConfig) -> [Workspace]`], "prod", "https://vault.prod.com")



Creates Vault Kubernetes authentication backends based on the provided configuration.```import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0 as vault_auth```



### `simpleVaultK8sAuth(name: str, clusterName: str, vaultAddr: str) -> [Workspace]`



Convenience function to create a single authentication backend with minimal configuration.### Full Configuration



### `multiVaultK8sAuth(auths: [K8sAuth], clusterName: str, vaultAddr: str) -> [Workspace]`



Creates multiple authentication backends with shared cluster and Vault settings.```kcl# Create a simple Vault K8s auth backend## 🚀 Usage



## Generated Resourcesimport oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 as vault_auth



This module creates Crossplane `Workspace` resources that contain Terraform configurations for:authBackend = vault_auth.simpleVaultK8sAuth(



- **Vault Provider**: Configured with authentication token from Kubernetes secretconfig = vault_auth.VaultConfig {

- **Vault Auth Backends**: Kubernetes authentication backends with unique paths

- **Variables**: Parameterized configuration for flexibility    k8sAuths = [    "my-app",                        # backend name### Quick Start Examples

- **Outputs**: Information about created auth backends

        vault_auth.K8sAuth {

## Prerequisites

            name = "application"    "prod-cluster",                  # cluster name

- Crossplane installed in your cluster

- crossplane-provider-terraform configured            clusterName = "prod"

- Vault server accessible from the cluster

- Vault authentication token stored in a Kubernetes secret            vaultAddr = "https://vault.prod.com"    "https://vault.example.com"      # vault address#### 1. Simple ServiceAccount Creation



## Example Terraform Output            skipTlsVerify = False



The module generates Terraform configurations like:            vaultTokenSecret = "vault-root-token")



```hcl            vaultTokenSecretNamespace = "vault-system"

provider "vault" {

  address         = var.vault_addr        }``````kcl

  skip_tls_verify = var.skip_tls_verify

  token           = var.vault_token    ]

}

    clusterName = "prod"import xplane_vault_auth as vault_auth

resource "vault_auth_backend" "kubernetes" {

  for_each = {    vaultAddr = "https://vault.prod.com"

    for auth in var.k8s_auths :

    auth.name => auth    skipTlsVerify = False### Multiple Authentication Backends

  }

    vaultTokenSecret = "vault-root-token"

  type = "kubernetes"

  path = "${var.cluster_name}-${each.value["name"]}"    vaultTokenSecretNamespace = "vault-system"# Define authentication configurations

}

```}



## Development```kclauths = [



### Running TestsauthBackends = vault_auth.vaultK8sAuth(config)



```bash```import oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0 as vault_auth    vault_auth.K8sAuth {

cd xplane-vault-auth

kcl run tests/test_main.k

```

## Schema Reference        name = "vault-auth-app"

### Running Examples



```bash

kcl run examples/vault-k8s-auth-corrected.k### VaultConfig# Configure multiple auth backends        namespace = "production"

```



### Validating Generated Resources

| Field | Type | Description | Default |multiAuth = vault_auth.multiVaultK8sAuth([    }

```bash

# Test resource generation and validation|-------|------|-------------|---------|

kcl run examples/vault-k8s-auth-corrected.k | kubectl apply --dry-run=client -f -

```| `k8sAuths` | `[K8sAuth]` | List of Kubernetes auth configurations | Required |    vault_auth.K8sAuth {    vault_auth.K8sAuth {



## Repository Structure| `clusterName` | `str` | Kubernetes cluster name | Required |



```| `vaultAddr` | `str` | Vault server address | Required |        name = "web-service"        name = "vault-auth-worker"

.

├── README.md| `skipTlsVerify` | `bool` | Skip TLS verification | `False` |

├── kcl.mod

├── main.k                           # Core module logic| `vaultTokenSecret` | `str` | Secret containing Vault token | `"vault-token"` |        clusterName = "prod"        namespace = "workers"

├── examples/

│   ├── vault-k8s-auth.k            # Basic usage examples| `vaultTokenSecretNamespace` | `str` | Namespace of token secret | `"vault-system"` |

│   └── vault-k8s-auth-corrected.k  # Working examples

└── tests/        vaultAddr = "https://vault.prod.com"        automountServiceAccountToken = False

    └── test_main.k                  # Test suite

```### K8sAuth



## Contributing    }    }



This module follows Stuttgart-Things standards:| Field | Type | Description | Default |



1. Use semantic versioning for releases|-------|------|-------------|---------|    vault_auth.K8sAuth {]

2. Add tests for new functionality

3. Update documentation for API changes| `name` | `str` | Authentication backend name | Required |

4. Follow KCL best practices

| `clusterName` | `str` | Kubernetes cluster name | Required |        name = "api-service"

## License

| `vaultAddr` | `str` | Vault server address | Required |

Apache License 2.0 - see LICENSE file for details.
| `skipTlsVerify` | `bool` | Skip TLS verification | `False` |        clusterName = "prod" # Create simple Terraform workspace

| `vaultTokenSecret` | `str` | Secret containing Vault token | `"vault-token"` |

| `vaultTokenSecretNamespace` | `str` | Namespace of token secret | `"vault-system"` |        vaultAddr = "https://vault.prod.com"workspace = vault_auth.simpleVaultAuth(



## Functions    }    "vault-authentication",



### `vaultK8sAuth(config: VaultConfig) -> [Workspace]`], "prod", "https://vault.prod.com")    auths



Creates Vault Kubernetes authentication backends based on the provided configuration.```)



### `simpleVaultK8sAuth(name: str, clusterName: str, vaultAddr: str) -> [Workspace]````



Convenience function to create a single authentication backend with minimal configuration.### Full Configuration



### `multiVaultK8sAuth(auths: [K8sAuth], clusterName: str, vaultAddr: str) -> [Workspace]`#### 2. Advanced Configuration with Connection Secrets



Creates multiple authentication backends with shared cluster and Vault settings.```kcl



## Generated Resourcesimport oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0 as vault_auth```kcl



This module creates Crossplane `Workspace` resources that contain Terraform configurations for:# Advanced setup with connection secrets



- **Vault Provider**: Configured with authentication token from Kubernetes secretconfig = vault_auth.VaultConfig {workspace = vault_auth.advancedVaultAuth(

- **Vault Auth Backends**: Kubernetes authentication backends with unique paths

- **Variables**: Parameterized configuration for flexibility    k8sAuths = [    "vault-auth-advanced",

- **Outputs**: Information about created auth backends

        vault_auth.K8sAuth {    "vault-system",

## Prerequisites

            name = "application"    auths,

- Crossplane installed in your cluster

- crossplane-provider-terraform configured            clusterName = "prod"    "vault-service-account-outputs"

- Vault server accessible from the cluster

- Vault authentication token stored in a Kubernetes secret            vaultAddr = "https://vault.prod.com")



## Example Terraform Output            skipTlsVerify = false```



The module generates Terraform configurations like:            vaultTokenSecret = "vault-root-token"



```hcl            vaultTokenSecretNamespace = "vault-system"#### 3. Full Configuration Control

provider "vault" {

  address         = var.vault_addr        }

  skip_tls_verify = var.skip_tls_verify

  token           = var.vault_token    ]```kcl

}

    clusterName = "prod"config = vault_auth.VaultAuthConfig {

resource "vault_auth_backend" "kubernetes" {

  for_each = {    vaultAddr = "https://vault.prod.com"    workspaceName = "vault-auth-complete"

    for auth in var.k8s_auths :

    auth.name => auth    skipTlsVerify = false    workspaceNamespace = "infrastructure"

  }

    vaultTokenSecret = "vault-root-token"

  type = "kubernetes"

  path = "${var.cluster_name}-${each.value["name"]}"    vaultTokenSecretNamespace = "vault-system"    k8sAuths = [

}

```}        vault_auth.K8sAuth {



## Development            name = "vault-auth-frontend"



### Running TestsauthBackends = vault_auth.vaultK8sAuth(config)            namespace = "frontend-prod"



```bash```        }

cd xplane-vault-auth

kcl run tests/test_main.k        vault_auth.K8sAuth {

```

## Schema Reference            name = "vault-auth-backend"

### Running Examples

            namespace = "backend-prod"

```bash

kcl run examples/vault-k8s-auth-corrected.k### VaultConfig            automountServiceAccountToken = True

```

        }

### Validating Generated Resources

| Field | Type | Description | Default |    ]

```bash

# Test resource generation and validation|-------|------|-------------|---------|

kcl run examples/vault-k8s-auth-corrected.k | kubectl apply --dry-run=client -f -

```| `k8sAuths` | `[K8sAuth]` | List of Kubernetes auth configurations | Required |    providerConfigRef = "terraform-k8s-provider"



## Repository Structure| `clusterName` | `str` | Kubernetes cluster name | Required |    connectionSecret = vault_auth.terraform.TerraformConnectionSecret {



```| `vaultAddr` | `str` | Vault server address | Required |        name = "vault-auth-results"

.

├── README.md| `skipTlsVerify` | `bool` | Skip TLS verification | `false` |        namespace = "infrastructure"

├── kcl.mod

├── main.k                           # Core module logic| `vaultTokenSecret` | `str` | Secret containing Vault token | `"vault-token"` |    }

├── examples/

│   ├── vault-k8s-auth.k            # Basic usage examples| `vaultTokenSecretNamespace` | `str` | Namespace of token secret | `"vault-system"` |

│   └── vault-k8s-auth-corrected.k  # Working examples

└── tests/    managementPolicies = ["Create", "Update", "Delete"]

    └── test_main.k                  # Test suite

```### K8sAuth    deletionPolicy = "Delete"



## Contributing}



This module follows Stuttgart-Things standards:| Field | Type | Description | Default |



1. Use semantic versioning for releases|-------|------|-------------|---------|workspace = vault_auth.generateVaultAuthWorkspace(config)

2. Add tests for new functionality

3. Update documentation for API changes| `name` | `str` | Authentication backend name | Required |```

4. Follow KCL best practices

| `clusterName` | `str` | Kubernetes cluster name | Required |

## License

| `vaultAddr` | `str` | Vault server address | Required |## 📚 Generated Terraform Code

Apache License 2.0 - see LICENSE file for details.
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