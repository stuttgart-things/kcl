# Vault Auth Module for Kubernetes Service Account Authentication
# This module provides Terraform-based authentication setup for Vault
import crossplane_provider_terraform as terraform

# Schema for Kubernetes Service Account Auth configuration
schema K8sAuth:
    name: str
    namespace?: str = "default"
    clusterName: str
    clusterRole?: str = "system:auth-delegator"
    vaultAddr: str
    vaultNamespace?: str = "default"
    authPath?: str = "kubernetes"
    tokenReviewerJwt?: str
    kubernetesCaCert?: str
    labels?: {str:str}
    annotations?: {str:str}

# Use the inlineTerraformWorkspace function from the terraform module

# Function to generate Terraform HCL for Kubernetes ServiceAccount
generateServiceAccountTerraform = lambda auth: K8sAuth -> str {
    """
# Kubernetes Service Account for Vault Authentication
resource "kubernetes_service_account" "vault_auth" {
  metadata {
    name      = "${auth.name}-vault-auth"
    namespace = "${auth.namespace}"
  }
}

# Cluster Role Binding for Service Account
resource "kubernetes_cluster_role_binding" "vault_auth" {
  metadata {
    name = "${auth.name}-vault-auth-delegator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "${auth.clusterRole}"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth.metadata[0].name
    namespace = "${auth.namespace}"
  }
}

# Secret for Service Account Token
resource "kubernetes_secret" "vault_auth_token" {
  metadata {
    name      = "${auth.name}-vault-auth-token"
    namespace = "${auth.namespace}"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_auth.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# Output the JWT token for Vault configuration
output "service_account_jwt" {
  value       = kubernetes_secret.vault_auth_token.data["token"]
  description = "JWT token for Vault Kubernetes authentication"
  sensitive   = true
}

output "kubernetes_ca_cert" {
  value       = kubernetes_secret.vault_auth_token.data["ca.crt"]
  description = "Kubernetes CA certificate for Vault authentication"
}

output "service_account_name" {
  value       = kubernetes_service_account.vault_auth.metadata[0].name
  description = "Name of the created service account"
}

output "service_account_namespace" {
  value       = "${auth.namespace}"
  description = "Namespace of the service account"
}
"""
}

# Main function to create Vault Kubernetes authentication setup
vaultK8sAuth = lambda auth: K8sAuth {
    terraformCode = generateServiceAccountTerraform(auth)
    variables = {
        "cluster_name" = auth.clusterName
        "vault_addr" = auth.vaultAddr
        "vault_namespace" = auth.vaultNamespace or "default"
        "auth_path" = auth.authPath or "kubernetes"
    }

    terraform.inlineTerraformWorkspace(name="{}-vault-k8s-auth".format(auth.name), terraformCode=terraformCode, format="HCL", variables=variables)
}

# Helper function for simple authentication setup
simpleVaultK8sAuth = lambda name: str, clusterName: str, vaultAddr: str {
    auth = K8sAuth {
        name = name
        clusterName = clusterName
        vaultAddr = vaultAddr
    }
    vaultK8sAuth(auth)
}

# Advanced authentication setup with custom configuration
advancedVaultK8sAuth = lambda auth: K8sAuth, customTerraformCode: str {
    terraformCode = customTerraformCode or generateServiceAccountTerraform(auth)
    variables = {
        "cluster_name" = auth.clusterName
        "vault_addr" = auth.vaultAddr
        "vault_namespace" = auth.vaultNamespace or "default"
        "auth_path" = auth.authPath or "kubernetes"
        "cluster_role" = auth.clusterRole or "system:auth-delegator"
    }

    terraform.inlineTerraformWorkspace(name="{}-vault-k8s-auth-advanced".format(auth.name), terraformCode=terraformCode, format="HCL", variables=variables)
}
