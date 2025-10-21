# Vault Auth Module for Kubernetes Authentication Backend
# This module creates Vault Kubernetes auth backends using Terraform

import crossplane_provider_terraform as terraform

# Schema for Kubernetes Auth Backend configuration
schema K8sAuth:
    name: str
    clusterName: str
    vaultAddr: str
    skipTlsVerify?: bool = False
    labels?: {str: str}
    annotations?: {str: str}

# Schema for Vault provider configuration
schema VaultConfig:
    k8sAuths: [K8sAuth]
    clusterName: str
    vaultAddr: str
    skipTlsVerify?: bool = False
    vaultTokenSecret?: str = "vault-token"
    vaultTokenSecretNamespace?: str = "vault-system"

# Function to generate Terraform HCL for Vault Kubernetes Auth Backend
generateVaultAuthTerraform = lambda config: VaultConfig -> str {
    r"""# Vault provider configuration with token from secret
provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = var.skip_tls_verify
  token           = var.vault_token
}

# Kubernetes auth backends for each auth configuration using count
resource "vault_auth_backend" "kubernetes" {
  count = length(var.k8s_auths)

  type = "kubernetes"
  path = "${var.cluster_name}-${var.k8s_auths[count.index].name}"
}

# Variables
variable "k8s_auths" {
  description = "List of Kubernetes auth configurations"
  type = list(object({
    name          = string
    cluster_name  = string
    vault_addr    = string
    skip_tls_verify = bool
  }))
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "vault_addr" {
  description = "Vault server address"
  type        = string
}

variable "skip_tls_verify" {
  description = "Skip TLS verification for Vault"
  type        = bool
  default     = false
}

variable "vault_token" {
  description = "Vault authentication token"
  type        = string
  sensitive   = true
}

# Outputs
output "auth_backends" {
  description = "Created Vault auth backends"
  value = [
    for i in range(length(var.k8s_auths)) :
    {
      path = vault_auth_backend.kubernetes[i].path
      type = vault_auth_backend.kubernetes[i].type
      name = var.k8s_auths[i].name
    }
  ]
}

output "auth_backend_names" {
  description = "List of created auth backend names"
  value = [for auth in var.k8s_auths : auth.name]
}"""
}

# Main function to create Vault Kubernetes authentication backends
vaultK8sAuth = lambda config: VaultConfig {
    terraformCode = generateVaultAuthTerraform(config)

    # Convert K8sAuth objects to variables format
    k8sAuthsVars = [
        {
            "name" = auth.name
            "cluster_name" = auth.clusterName
            "vault_addr" = auth.vaultAddr
            "skip_tls_verify" = str(auth.skipTlsVerify or False)
        } for auth in config.k8sAuths
    ]

    variables = {
        "k8s_auths" = str(k8sAuthsVars)
        "cluster_name" = config.clusterName
        "vault_addr" = config.vaultAddr
        "skip_tls_verify" = str(config.skipTlsVerify or False)
    }

    terraform.inlineTerraformWorkspace(
        name = "{}-vault-k8s-auth".format(config.clusterName)
        terraformCode = terraformCode
        format = "HCL"
        variables = variables
    )
}

# Helper function for simple authentication setup
simpleVaultK8sAuth = lambda name: str, clusterName: str, vaultAddr: str {
    config = VaultConfig {
        k8sAuths = [K8sAuth {
            name = name
            clusterName = clusterName
            vaultAddr = vaultAddr
        }]
        clusterName = clusterName
        vaultAddr = vaultAddr
    }
    vaultK8sAuth(config)
}

# Advanced authentication setup with multiple auth backends
multiVaultK8sAuth = lambda auths: [K8sAuth], clusterName: str, vaultAddr: str {
    config = VaultConfig {
        k8sAuths = auths
        clusterName = clusterName
        vaultAddr = vaultAddr
    }
    vaultK8sAuth(config)
}
