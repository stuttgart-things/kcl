import main as vault_auth

# --- Get XR spec fields ---
clusterName = option("params")?.oxr?.spec?.clusterName or "default"
vaultAddr = option("params")?.oxr?.spec?.vaultAddr or "https://vault.example.com"

_simpleAuth = vault_auth.simpleVaultK8sAuth(
    name = "my-app"
    clusterName = clusterName
    vaultAddr = vaultAddr
)

# Overwrite providerConfigRef
items = [
    item | {
        spec.providerConfigRef.name = clusterName
    } for item in _simpleAuth
]
