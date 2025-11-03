# Vault Auth Module for Kubernetes Authentication Backend
# This module creates Vault Kubernetes auth backends using Terraform

import crossplane_provider_terraform as terraform

# Schema for Kubernetes Auth Backend configuration
schema K8sAuth:
    name: str
    clusterName: str
    vaultAddr: str
    skipTlsVerify?: bool = False
    tokenPolicies?: [str] = []
    tokenTtl?: int = 3600
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

# Function to generate Terraform HCL for a single Vault Kubernetes Auth Backend
generateSingleVaultAuthTerraform = lambda auth: K8sAuth -> str {
    r"""# Vault provider configuration with token from secret
provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = var.skip_tls_verify
  token           = var.vault_token
}

# Single Kubernetes auth backend
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "${var.cluster_name}-${var.auth_name}"
}

# Auth backend role for the service account
resource "vault_kubernetes_auth_backend_role" "service_account" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.auth_name
  bound_service_account_names      = [var.auth_name]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = var.token_ttl
  token_policies                   = var.token_policies
}

# Variables
variable "auth_name" {
  description = "Authentication backend name"
  type        = string
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

variable "token_policies" {
  description = "List of policies for the auth backend"
  type        = list(string)
  default     = []
}

variable "token_ttl" {
  description = "Token TTL in seconds"
  type        = number
  default     = 3600
}

# Outputs
output "auth_backend_path" {
  description = "Path of the created auth backend"
  value       = vault_auth_backend.kubernetes.path
}

output "auth_role_name" {
  description = "Name of the created auth role"
  value       = vault_kubernetes_auth_backend_role.service_account.role_name
}"""
}

# Function to create a single Vault Kubernetes auth backend
createSingleVaultAuth = lambda auth: K8sAuth {
    terraformCode = generateSingleVaultAuthTerraform(auth)

    variables = {
        "auth_name" = auth.name
        "cluster_name" = auth.clusterName
        "vault_addr" = auth.vaultAddr
        "skip_tls_verify" = str(auth.skipTlsVerify or False)
        "token_policies" = str(auth.tokenPolicies or [])
        "token_ttl" = str(auth.tokenTtl or 3600)
    }

    terraform.inlineTerraformWorkspace(
        name = "{}-{}-vault-auth".format(auth.clusterName, auth.name)
        terraformCode = terraformCode
        format = "HCL"
        variables = variables
    )
}

# Main function - now returns a flat list
vaultK8sAuth = lambda config: VaultConfig {
    [createSingleVaultAuth(auth) for auth in config.k8sAuths]
}

# Simple helper function for basic authentication setup
simpleVaultK8sAuth = lambda name: str, clusterName: str, vaultAddr: str {
    auth = K8sAuth {
        name = name
        clusterName = clusterName
        vaultAddr = vaultAddr
    }
    createSingleVaultAuth(auth)
}

# Simple helper with policies
simpleVaultK8sAuthWithPolicies = lambda name: str, clusterName: str, vaultAddr: str, policies: [str] {
    auth = K8sAuth {
        name = name
        clusterName = clusterName
        vaultAddr = vaultAddr
        tokenPolicies = policies
    }
    createSingleVaultAuth(auth)
}

# Helper function for authentication with custom TTL and policies
advancedVaultK8sAuth = lambda name: str, clusterName: str, vaultAddr: str, policies: [str], ttl: int {
    auth = K8sAuth {
        name = name
        clusterName = clusterName
        vaultAddr = vaultAddr
        tokenPolicies = policies
        tokenTtl = ttl
    }
    createSingleVaultAuth(auth)
}

# Multiple auth backends (creates separate workspaces for each)
multiVaultK8sAuth = lambda auths: [K8sAuth], clusterName: str, vaultAddr: str {
    config = VaultConfig {
        k8sAuths = auths
        clusterName = clusterName
        vaultAddr = vaultAddr
    }
    vaultK8sAuth(config)
}
