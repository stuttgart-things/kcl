import xplane_vault_auth_base as vault_auth

_params = option("params") or {}
_spec = _params?.oxr?.spec or {}

_clusterName = _spec?.clusterName or "default"
_vaultAddr = _spec?.vaultAddr or "https://vault.example.com"
_namespace = _spec?.namespace or "default"
_vaultTokenSecret = _spec?.vaultTokenSecret or "vault"
_vaultTokenSecretKey = _spec?.vaultTokenSecretKey or "terraform.tfvars"
_providerConfigName = _spec?.providerConfigName or _clusterName
_providerConfigKind = _spec?.providerConfigKind or "ClusterProviderConfig"
_skipTlsVerify = _spec?.skipTlsVerify if "skipTlsVerify" in _spec else True

_k8sAuths = [
    vault_auth.K8sAuth {
        name = auth?.name or "default"
        clusterName = auth?.clusterName or _clusterName
        vaultAddr = auth?.vaultAddr or _vaultAddr
        skipTlsVerify = auth?.skipTlsVerify if "skipTlsVerify" in auth else _skipTlsVerify
        tokenPolicies = auth?.tokenPolicies or ["read-secrets"]
        tokenTtl = auth?.tokenTtl or 3600
        boundServiceAccountNamespaces = auth?.boundServiceAccountNamespaces or ["default"]
    } for auth in (_spec?.k8sAuths or [
        {"name": "frontend", "tokenPolicies": ["read-secrets"], "tokenTtl": 7200},
        {"name": "backend", "tokenPolicies": ["read-secrets", "write-logs"], "tokenTtl": 3600},
    ])
]

_config = vault_auth.VaultConfig {
    k8sAuths = _k8sAuths
    clusterName = _clusterName
    vaultAddr = _vaultAddr
    skipTlsVerify = _skipTlsVerify
    namespace = _namespace
    vaultTokenSecret = _vaultTokenSecret
    vaultTokenSecretKey = _vaultTokenSecretKey
    providerConfigName = _providerConfigName
    providerConfigKind = _providerConfigKind
}

items = vault_auth.vaultK8sAuth(_config)
