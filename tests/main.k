# Vault Auth Module for Kubernetes Service Account Authentication
# This module provides Terraform-based authentication setup for Vault

# Temporary inline schemas (until crossplane-provider-terraform is published to OCI)
schema TerraformWorkspace:
    apiVersion: str = "tf.crossplane.io/v1beta1"
    kind: str = "Workspace"
    metadata: {
        name: str
        namespace?: str = "default"
        labels?: {str: str}
        annotations?: {str: str}
    }
    spec: {
        deletionPolicy?: str = "Delete"
        managementPolicies?: [str] = ["*"]
        providerConfigRef?: {
            name: str
        }
        writeConnectionSecretToRef?: {
            name: str
            namespace?: str
        }
        forProvider: {
            source: str = "Inline"
            module?: str
            inlineFormat?: str = "HCL"
            vars?: [{
                key: str
                value: str
            }]
        }
    }

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
    labels?: {str: str}
    annotations?: {str: str}

# Function to create inline Terraform workspace
inlineTerraformWorkspace = lambda name: str, terraformCode: str, format: str = "HCL", variables: {str: str} = {} -> TerraformWorkspace {
    TerraformWorkspace {
        metadata = {
            name = name
        }
        spec = {
            forProvider = {
                source = "Inline"
                inlineFormat = format
                module = terraformCode
                vars = [
                    {
                        key = k
                        value = v
                    } for k, v in variables
                ]
            }
        }
    }
}

# Function to generate Terraform HCL for Kubernetes ServiceAccount
generateServiceAccountTerraform = lambda auth: K8sAuth -> str {
    f"""
# Kubernetes Service Account for Vault Authentication
resource "kubernetes_service_account" "vault_auth" {{
  metadata {{
    name      = "{auth.name}-vault-auth"
    namespace = "{auth.namespace}"
    {f'labels = {' '.join([f'"{k}" = "{v}"' for k, v in auth.labels])}' if auth.labels else ''}
    {f'annotations = {' '.join([f'"{k}" = "{v}"' for k, v in auth.annotations])}' if auth.annotations else ''}
  }}
}}

# Cluster Role Binding for Service Account
resource "kubernetes_cluster_role_binding" "vault_auth" {{
  metadata {{
    name = "{auth.name}-vault-auth-delegator"
  }}
  role_ref {{
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "{auth.clusterRole}"
  }}
  subject {{
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth.metadata[0].name
    namespace = "{auth.namespace}"
  }}
}}

# Secret for Service Account Token (if needed for older Kubernetes versions)
resource "kubernetes_secret" "vault_auth_token" {{
  metadata {{
    name      = "{auth.name}-vault-auth-token"
    namespace = "{auth.namespace}"
    annotations = {{
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_auth.metadata[0].name
    }}
  }}
  type = "kubernetes.io/service-account-token"
}}

# Output the JWT token for Vault configuration
output "service_account_jwt" {{
  value       = kubernetes_secret.vault_auth_token.data["token"]
  description = "JWT token for Vault Kubernetes authentication"
  sensitive   = true
}}

output "kubernetes_ca_cert" {{
  value       = kubernetes_secret.vault_auth_token.data["ca.crt"]
  description = "Kubernetes CA certificate for Vault authentication"
}}

output "service_account_name" {{
  value       = kubernetes_service_account.vault_auth.metadata[0].name
  description = "Name of the created service account"
}}

output "service_account_namespace" {{
  value       = "{auth.namespace}"
  description = "Namespace of the service account"
}}
"""
}

# Main function to create Vault Kubernetes authentication setup
vaultK8sAuth = lambda auth: K8sAuth -> [TerraformWorkspace] {
    terraformCode = generateServiceAccountTerraform(auth)
    variables = {
        "cluster_name" = auth.clusterName
        "vault_addr" = auth.vaultAddr
        "vault_namespace" = auth.vaultNamespace
        "auth_path" = auth.authPath
    }

    [
        inlineTerraformWorkspace(
            name = f"{auth.name}-vault-k8s-auth"
            terraformCode = terraformCode
            format = "HCL"
            variables = variables
        )
    ]
}

# Helper function for simple authentication setup
simpleVaultK8sAuth = lambda name: str, clusterName: str, vaultAddr: str -> [TerraformWorkspace] {
    auth = K8sAuth {
        name = name
        clusterName = clusterName
        vaultAddr = vaultAddr
    }
    vaultK8sAuth(auth)
}

# Advanced authentication setup with custom configuration
advancedVaultK8sAuth = lambda auth: K8sAuth, customTerraformCode?: str -> [TerraformWorkspace] {
    terraformCode = customTerraformCode or generateServiceAccountTerraform(auth)
    variables = {
        "cluster_name" = auth.clusterName
        "vault_addr" = auth.vaultAddr
        "vault_namespace" = auth.vaultNamespace or "default"
        "auth_path" = auth.authPath or "kubernetes"
        "cluster_role" = auth.clusterRole or "system:auth-delegator"
    }

    [
        inlineTerraformWorkspace(
            name = f"{auth.name}-vault-k8s-auth-advanced"
            terraformCode = terraformCode
            format = "HCL"
            variables = variables
        )
    ]
}
