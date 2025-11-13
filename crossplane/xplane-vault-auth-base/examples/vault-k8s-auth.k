import ..main as vault_auth

# --- Read parameters ---
_params = option("params") or {}
_spec = _params?.oxr?.spec or {}

# --- Extract fields with defaults ---
_clusterName = _spec?.clusterName or "default"
_vaultAddr = _spec?.vaultAddr or "https://vault.example.com"
_vaultTokenSecret = _spec?.vaultTokenSecret or "vault"
_vaultTokenSecretNamespace = _spec?.vaultTokenSecretNamespace or "crossplane-system"
_vaultTokenSecretKey = _spec?.vaultTokenSecretKey or "terraform.tfvars"

# --- Allow overriding of k8sAuth entries via params ---
_k8sAuths = [
    # If user provides params.oxr.spec.k8sAuths, use those dynamically
    vault_auth.K8sAuth {
        name = auth?.name or "default"
        clusterName = auth?.clusterName or _clusterName
        vaultAddr = auth?.vaultAddr or _vaultAddr
        skipTlsVerify = auth?.skipTlsVerify or True
        tokenPolicies = auth?.tokenPolicies or ["read-secrets"]
        tokenTtl = auth?.tokenTtl or 3600
        boundServiceAccountNamespaces = auth?.boundServiceAccountNamespaces or ["default"]
    } for auth in (_spec?.k8sAuths or [
        {"name": "frontend", "tokenPolicies": ["read-secrets"], "tokenTtl": 7200},
        {"name": "backend", "tokenPolicies": ["read-secrets", "write-logs"], "tokenTtl": 3600},
    ])
]

# --- Build VaultConfig dynamically ---
_config = vault_auth.VaultConfig {
    k8sAuths = _k8sAuths
    clusterName = _clusterName
    vaultAddr = _vaultAddr
    skipTlsVerify = True
    vaultTokenSecret = _vaultTokenSecret
    vaultTokenSecretNamespace = _vaultTokenSecretNamespace
    vaultTokenSecretKey = _vaultTokenSecretKey
}

# --- Generate Vault auth workspaces ---
_generatedWorkspaces = vault_auth.vaultK8sAuth(_config)

# --- Flatten and add providerConfigRef (varFiles already added in main module) ---
items = [
    workspace | {
        spec.providerConfigRef.name = _clusterName
    } for workspaceList in _generatedWorkspaces for workspace in workspaceList
]
