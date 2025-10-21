import main as vault_auth

# Simple example for Vault K8s authentication
simpleAuth = vault_auth.simpleVaultK8sAuth(
    name = "my-app"
    clusterName = "production"
    vaultAddr = "https://vault.example.com"
)

# Advanced example with custom configuration
advancedAuth = vault_auth.vaultK8sAuth(vault_auth.K8sAuth {
    name = "advanced-app"
    namespace = "my-namespace"
    clusterName = "production"
    clusterRole = "system:auth-delegator"
    vaultAddr = "https://vault.example.com"
    vaultNamespace = "my-vault-namespace"
    authPath = "kubernetes-prod"
    labels = {
        "app" = "my-app"
        "version" = "v1.0.0"
    }
    annotations = {
        "vault.security.banzaicloud.io/vault-addr" = "https://vault.example.com"
    }
})

# Output both configurations
manifests = simpleAuth + advancedAuth