# Examples for Vault Authentication Module
# Demonstrates various ways to create ServiceAccounts for Vault authentication

import ..main as vault_auth

# Example 1: Simple ServiceAccount creation
simple_auths = [
    vault_auth.K8sAuth {
        name = "vault-auth-prod"
        namespace = "production"
    }
    vault_auth.K8sAuth {
        name = "vault-auth-staging"
        namespace = "staging" 
        automountServiceAccountToken = True
    }
]

simple_workspace = vault_auth.simpleVaultAuth(
    "simple-vault-auth",
    simple_auths
)

# Example 2: Advanced configuration with connection secrets
advanced_auths = [
    vault_auth.K8sAuth {
        name = "vault-auth-webapp"
        namespace = "webapp-prod"
    }
    vault_auth.K8sAuth {
        name = "vault-auth-database"
        namespace = "database-prod"
        automountServiceAccountToken = False
    }
    vault_auth.K8sAuth {
        name = "vault-auth-monitoring"
        namespace = "monitoring"
    }
]

advanced_workspace = vault_auth.advancedVaultAuth(
    "advanced-vault-auth",
    "vault-system",
    advanced_auths,
    "vault-auth-outputs"
)

# Example 3: Full configuration with custom settings
full_config = vault_auth.VaultAuthConfig {
    workspaceName = "full-vault-auth"
    workspaceNamespace = "infrastructure"
    
    k8sAuths = [
        vault_auth.K8sAuth {
            name = "vault-auth-frontend"
            namespace = "frontend"
        }
        vault_auth.K8sAuth {
            name = "vault-auth-backend"
            namespace = "backend"
            automountServiceAccountToken = True
        }
        vault_auth.K8sAuth {
            name = "vault-auth-worker" 
            namespace = "workers"
            automountServiceAccountToken = False
        }
    ]
    
    providerConfigRef = "terraform-kubernetes-provider"
    connectionSecret = vault_auth.TerraformConnectionSecret {
        name = "vault-service-accounts"
        namespace = "infrastructure"
    }
    
    managementPolicies = ["Create", "Update", "Delete"]
    deletionPolicy = "Delete"
}

full_workspace = vault_auth.generateVaultAuthWorkspace(full_config)

# Example 4: Multi-environment setup
environments = ["dev", "staging", "prod"]
multi_env_workspaces = [
    vault_auth.simpleVaultAuth(
        "vault-auth-{}".format(env),
        [
            vault_auth.K8sAuth {
                name = "vault-auth-app"
                namespace = "{}-applications".format(env)
            }
            vault_auth.K8sAuth {
                name = "vault-auth-data"
                namespace = "{}-data".format(env)
            }
        ]
    ) for env in environments
]

# Flatten the multi-environment workspaces
multi_env_flat = []
for workspace_list in multi_env_workspaces:
    multi_env_flat += workspace_list

# Render all examples
all_workspaces = simple_workspace + advanced_workspace + full_workspace + multi_env_flat