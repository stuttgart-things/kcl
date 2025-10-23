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
        skipTlsVerify = False
    }
    vault_auth.K8sAuth {
        name = "api-service"
        clusterName = "prod"
        vaultAddr = "https://vault.prod.com"
        skipTlsVerify = False
    }
    vault_auth.K8sAuth {
        name = "worker"
        clusterName = "prod"
        vaultAddr = "https://vault.prod.com"
        skipTlsVerify = False
    }
], "prod", "https://vault.prod.com")

# Example: Full Configuration with Custom Settings
fullConfig = vault_auth.VaultConfig {
    k8sAuths = [
        vault_auth.K8sAuth {
            name = "frontend"
            clusterName = "staging"
            vaultAddr = "https://vault.staging.com"
            skipTlsVerify = True  # for development environments
        }
        vault_auth.K8sAuth {
            name = "backend"
            clusterName = "staging"
            vaultAddr = "https://vault.staging.com"
            skipTlsVerify = True
        }
    ]
    clusterName = "staging"
    vaultAddr = "https://vault.staging.com"
    skipTlsVerify = True
    vaultTokenSecret = "custom-vault-token" # pragma: allowlist secret
    vaultTokenSecretNamespace = "security" # pragma: allowlist secret
}

fullAuth = vault_auth.vaultK8sAuth(fullConfig)

# Output the resources
simple = simpleAuth[0]
multi = multiAuth[0]
full = fullAuth[0]
