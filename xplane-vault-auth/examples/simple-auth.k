import main as vault_auth

# Simple example for Vault K8s authentication backend
simpleAuth = vault_auth.simpleVaultK8sAuth(
    name = "my-app"
    clusterName = "production"
    vaultAddr = "https://vault.example.com"
)

# Advanced example with multiple auth backends
multiAuth = vault_auth.multiVaultK8sAuth(
    auths = [
        vault_auth.K8sAuth {
            name = "frontend"
            clusterName = "production"
            vaultAddr = "https://vault.example.com"
        }
        vault_auth.K8sAuth {
            name = "backend"
            clusterName = "production"
            vaultAddr = "https://vault.example.com"
        }
        vault_auth.K8sAuth {
            name = "workers"
            clusterName = "production"
            vaultAddr = "https://vault.example.com"
            skipTlsVerify = true
        }
    ]
    clusterName = "production"
    vaultAddr = "https://vault.example.com"
)

# Full configuration example
fullConfig = vault_auth.vaultK8sAuth(vault_auth.VaultConfig {
    k8sAuths = [
        vault_auth.K8sAuth {
            name = "app-team-1"
            clusterName = "production"
            vaultAddr = "https://vault.example.com"
            labels = {
                "team" = "app-team-1"
                "environment" = "production"
            }
        }
        vault_auth.K8sAuth {
            name = "app-team-2"
            clusterName = "production"
            vaultAddr = "https://vault.example.com"
            labels = {
                "team" = "app-team-2"
                "environment" = "production"
            }
        }
    ]
    clusterName = "production"
    vaultAddr = "https://vault.example.com"
    skipTlsVerify = false
    vaultTokenSecret = "vault-token" # pragma: allowlist secret
    vaultTokenSecretNamespace = "vault-system" # pragma: allowlist secret
})

# Output all configurations
manifests = [simpleAuth] + [multiAuth] + [fullConfig]
