# Vault Authentication KCL Module
# Creates Kubernetes ServiceAccounts for Vault authentication using Terraform

import crossplane_provider_terraform as terraform

# Schema for Kubernetes authentication configuration
schema K8sAuth:
    """
    Kubernetes authentication configuration for Vault.
    
    Defines ServiceAccount and authentication setup parameters.
    """
    name: str
    namespace: str
    automountServiceAccountToken?: bool = True

# Schema for Vault authentication workspace configuration
schema VaultAuthConfig:
    """
    Complete Vault authentication configuration.
    
    Combines workspace settings with Kubernetes authentication details.
    """
    # Workspace configuration
    workspaceName: str
    workspaceNamespace?: str = "vault-system"
    
    # Kubernetes authentications to create
    k8sAuths: [K8sAuth]
    
    # Terraform workspace configuration
    providerConfigRef?: str = "default"
    connectionSecret?: terraform.TerraformConnectionSecret
    
    # Management policies
    managementPolicies?: [str] = ["*"]
    deletionPolicy?: "Delete" | "Orphan" = "Delete"

# Function to generate Terraform inline code for ServiceAccounts
generateTerraformCode = lambda auths: [K8sAuth] -> str {
    """
    Generate Terraform HCL code for creating Kubernetes ServiceAccounts.
    
    Args:
        auths: List of K8sAuth configurations
        
    Returns:
        Terraform HCL code as string
    """
    
    # Variable definition for k8s_auths
    variables = """
variable "k8s_auths" {
  description = "List of Kubernetes authentications to create"
  type = list(object({
    name      = string
    namespace = string
    automountServiceAccountToken = optional(bool, true)
  }))
  default = []
}
"""
    
    # Resource definition for ServiceAccounts
    resources = """
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
"""
    
    # Output definition for created ServiceAccounts
    outputs = """
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
"""
    
    variables + resources + outputs
}

# Function to convert K8sAuth objects to Terraform variables format
authsToTerraformVars = lambda auths: [K8sAuth] -> {str: str} {
    """
    Convert K8sAuth configurations to Terraform variable format.
    
    Args:
        auths: List of K8sAuth configurations
        
    Returns:
        Terraform variables as key-value pairs
    """
    
    # Convert to JSON format for Terraform list(object()) variable
    authsJson = [
        {
            "name" = auth.name
            "namespace" = auth.namespace  
            "automountServiceAccountToken" = auth.automountServiceAccountToken
        } for auth in auths
    ]
    
    {
        "k8s_auths" = str(authsJson)
    }
}

# Main function to generate Vault authentication workspace
generateVaultAuthWorkspace = lambda config: VaultAuthConfig -> [any] {
    """
    Generate Terraform workspace for Vault authentication setup.
    
    Args:
        config: VaultAuthConfig with workspace and auth settings
        
    Returns:
        List containing the Terraform workspace resource
    """
    
    # Generate Terraform code
    terraformCode = generateTerraformCode(config.k8sAuths)
    
    # Generate variables
    terraformVars = authsToTerraformVars(config.k8sAuths)
    
    # Create Terraform workspace using inline provider
    terraform.inlineTerraformWorkspace(
        config.workspaceName,
        terraformCode,
        "HCL",
        terraformVars
    )
}

# Helper function for simple ServiceAccount creation
simpleVaultAuth = lambda workspaceName: str, auths: [K8sAuth] -> [any] {
    """
    Simple helper for creating Vault authentication ServiceAccounts.
    
    Args:
        workspaceName: Name of the Terraform workspace
        auths: List of ServiceAccount configurations
        
    Returns:
        List containing the Terraform workspace resource
    """
    
    generateVaultAuthWorkspace(VaultAuthConfig {
        workspaceName = workspaceName
        k8sAuths = auths
    })
}

# Advanced helper with full configuration
advancedVaultAuth = lambda workspaceName: str, namespace: str, auths: [K8sAuth], secretName: str -> [any] {
    """
    Advanced helper with connection secrets and custom namespace.
    
    Args:
        workspaceName: Name of the Terraform workspace
        namespace: Kubernetes namespace for workspace
        auths: List of ServiceAccount configurations
        secretName: Name for connection secret
        
    Returns:
        List containing the Terraform workspace resource
    """
    
    generateVaultAuthWorkspace(VaultAuthConfig {
        workspaceName = workspaceName
        workspaceNamespace = namespace
        k8sAuths = auths
        connectionSecret = terraform.TerraformConnectionSecret {
            name = secretName
            namespace = namespace
        }
    })
}