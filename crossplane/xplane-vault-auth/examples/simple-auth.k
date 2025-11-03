import main as vault_auth

# Simple example for Vault K8s authentication backend
_simpleAuth = vault_auth.simpleVaultK8sAuth(
    name = "my-app"
    clusterName = "production"
    vaultAddr = "https://vault.example.com"
)

# Generate items conditionally
items = _simpleAuth
