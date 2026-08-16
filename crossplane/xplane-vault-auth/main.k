import .logic as l
import xplane_vault_auth_base as vault_auth

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}
_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}

_clusterName = _spec?.clusterName or "default"
_vaultAddr = _spec?.vaultAddr or "https://vault.example.com"
_namespace = _spec?.namespace or _meta?.namespace or "default"
_vaultTokenSecret = _spec?.vaultTokenSecret or "vault"
_vaultTokenSecretKey = _spec?.vaultTokenSecretKey or "terraform.tfvars"
_providerConfigName = _spec?.providerConfigName or _clusterName
_providerConfigKind = _spec?.providerConfigKind or "ClusterProviderConfig"
_skipTlsVerify = _spec.skipTlsVerify if "skipTlsVerify" in _spec else True
_kubernetesHost = _spec?.kubernetesHost or ""

_buildBackendConfig = lambda bc: any -> vault_auth.K8sAuthBackendConfig {
    vault_auth.K8sAuthBackendConfig {
        secretName = bc?.secretName or "vault-default"
        secretNamespace = bc?.secretNamespace
        caCertKey = bc?.caCertKey or "ca.crt"
        tokenKey = bc?.tokenKey or "token"
        disableIssValidation = bc.disableIssValidation if bc and "disableIssValidation" in bc else True
        disableLocalCaJwt = bc.disableLocalCaJwt if bc and "disableLocalCaJwt" in bc else True
    } if bc else Undefined
}

_k8sAuths = [vault_auth.K8sAuth {
    name = auth?.name or "default"
    clusterName = auth?.clusterName or _clusterName
    vaultAddr = auth?.vaultAddr or _vaultAddr
    skipTlsVerify = auth.skipTlsVerify if "skipTlsVerify" in auth else _skipTlsVerify
    tokenPolicies = auth?.tokenPolicies or ["read-secrets"]
    tokenTtl = auth?.tokenTtl or 3600
    boundServiceAccountNames = auth?.boundServiceAccountNames or ["default"]
    boundServiceAccountNamespaces = auth?.boundServiceAccountNamespaces or ["default"]
    # Policies to CREATE for this auth, each named {clusterName}-{name} and
    # appended to tokenPolicies. A cluster usually wants more than one: its own
    # KV subtree, plus whatever the role it plays grants it.
    policies = [vault_auth.VaultPolicy {
        name = p?.name or "default"
        kvMount = p?.kvMount or ""
        read = p?.read or []
    } for p in (auth?.policies or [])]
    backendConfig = _buildBackendConfig(auth?.backendConfig)
} for auth in (_spec?.k8sAuths or [
    {"name": "frontend", "tokenPolicies": ["read-secrets"], "tokenTtl": 7200}
    {"name": "backend", "tokenPolicies": ["read-secrets", "write-logs"], "tokenTtl": 3600}
])]

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
    kubernetesHost = _kubernetesHost
}

# --- status ----------------------------------------------------------------
# The OpenTofu Workspace publishes what a consumer needs — the mount path Vault
# created, the role name, and now the policies created for it. Nothing lifted
# them, so a VaultK8sAuth reported readiness and nothing else, and anything
# wanting to USE the mount had to be told its name by hand.
#
# Not cosmetic: external-secrets needs exactly these values, and without them a
# catalog entry cannot discover its own cluster's Vault mount
# (crossplane-configurations#260).
#
# A LIST rather than a map keyed by name: `k8sAuths` is a list, one auth per
# Workspace, and the status mirrors what was asked for rather than reshaping it.
#
# Matched by the Workspace's metadata.name rather than the ocds key, because the
# base module fills composition-resource-name from `auth.annotations` and an XR
# that passes none would otherwise be unmatchable.
_wsNamed = lambda n: str -> any {
    _m = [v.Resource for _, v in _ocds if v?.Resource?.metadata?.name == n]
    _m[0] if _m else {}
}

_auths = [l.authStatus(a.clusterName, a.name, _wsNamed(l.workspaceName(a.clusterName, a.name))) for a in _k8sAuths]

_statusPatch = {
    apiVersion = _oxr?.apiVersion
    kind = _oxr?.kind
    metadata = {
        name = _meta?.name
        namespace = _meta?.namespace
    }
    status = {
        share = {
            clusterName = _clusterName
            vaultAddr = _vaultAddr
            auths = _auths
            ready = l.allReady(_auths)
        }
    }
}

items = vault_auth.vaultK8sAuth(_config) + [_statusPatch]
