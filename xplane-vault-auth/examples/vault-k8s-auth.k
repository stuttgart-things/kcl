import ..main as vault_auth

# Example: Simple Vault K8s Auth Backend
simpleAuth = vault_auth.simpleVaultK8sAuth(
    "application-backend",           # backend name
    "prod-cluster",                  # cluster name
    "https://vault.example.com"      # vault address
)

# Example: Multiple Auth Backends
multiAuth = vault_auth.multiVaultK8sAuth([
    vault_auth.K8sAuth {
        name = "web-app"
        clusterName = "prod"
        vaultAddr = "https://vault.prod.com"
        skipTlsVerify = false
    }
    vault_auth.K8sAuth {
        name = "api-service"
        clusterName = "prod"
        vaultAddr = "https://vault.prod.com"
        skipTlsVerify = false
    }
    vault_auth.K8sAuth {
        name = "worker"
        clusterName = "prod"
        vaultAddr = "https://vault.prod.com"
        skipTlsVerify = false
    }
], "prod", "https://vault.prod.com")

# Example: Full Configuration with Custom Settings
fullConfig = vault_auth.VaultConfig {
    k8sAuths = [
        vault_auth.K8sAuth {
            name = "frontend"
            clusterName = "staging"
            vaultAddr = "https://vault.staging.com"
            skipTlsVerify = true  # for development environments
            vaultTokenSecret = "custom-vault-token"
            vaultTokenSecretNamespace = "security"
        }
        vault_auth.K8sAuth {
            name = "backend"
            clusterName = "staging"
            vaultAddr = "https://vault.staging.com"
            skipTlsVerify = true
            vaultTokenSecret = "custom-vault-token"
            vaultTokenSecretNamespace = "security"
        }
    ]
    clusterName = "staging"
    vaultAddr = "https://vault.staging.com"
    skipTlsVerify = true
    vaultTokenSecret = "custom-vault-token"
    vaultTokenSecretNamespace = "security"
}

fullAuth = vault_auth.vaultK8sAuth(fullConfig)

# Output the resources
[simpleAuth[0], multiAuth[0], fullAuth[0]]