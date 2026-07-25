import main as vault_auth

# --- Config with two auths: one plain, one with backendConfig ---
_config = vault_auth.VaultConfig {
    clusterName = "test-cluster"
    vaultAddr = "https://vault.test.com"
    skipTlsVerify = True
    namespace = "default"
    kubernetesHost = "https://10.0.0.1:6443"
    k8sAuths = [
        vault_auth.K8sAuth {
            name = "certmanager"
            clusterName = "test-cluster"
            vaultAddr = "https://vault.test.com"
            tokenPolicies = ["pki-issue"]
            boundServiceAccountNames = ["cert-manager"]
            boundServiceAccountNamespaces = ["cert-manager"]
        }
        vault_auth.K8sAuth {
            name = "cicd"
            clusterName = "test-cluster"
            vaultAddr = "https://vault.test.com"
            tokenPolicies = ["read-secrets"]
            backendConfig = vault_auth.K8sAuthBackendConfig {
                secretName = "reviewer-token"
                secretNamespace = "kube-system"
            }
        }
    ]
}

_workspaces = vault_auth.vaultK8sAuth(_config)
assert len(_workspaces) == 2

_plain = [w for w in _workspaces if w.metadata.name == "test-cluster-certmanager-vault-auth"][0]
_withCfg = [w for w in _workspaces if w.metadata.name == "test-cluster-cicd-vault-auth"][0]

# --- AppRole login, NOT a static token ---
_pm = _plain.spec.forProvider.module
assert "auth_login {" in _pm, "provider must use auth_login (AppRole)"
assert 'path = "auth/approle/login"' in _pm
assert "skip_child_token = true" in _pm
assert "var.vault_role_id" in _pm
assert "var.vault_secret_id" in _pm
assert "token           = var.vault_token" not in _pm, "static token block must be gone"
assert 'variable "vault_role_id"' in _pm
assert 'variable "vault_secret_id"' in _pm

# --- required_providers pins vault ~> 3.25 ---
assert "required_providers" in _pm
assert 'version = "~> 3.25"' in _pm
# plain auth pulls no kubernetes provider
assert "hashicorp/kubernetes" not in _pm

# --- credentials still injected via the tfvars SecretKey varFile ---
_vf = _plain.spec.forProvider.varFiles[0]
assert _vf.source == "SecretKey"
assert _vf.secretKeyRef.key == "terraform.tfvars"

# --- backendConfig auth adds the kubernetes provider + backend_config resource ---
_cm = _withCfg.spec.forProvider.module
assert "hashicorp/kubernetes" in _cm, "backendConfig must pull the kubernetes provider"
assert "vault_kubernetes_auth_backend_config" in _cm
assert "token_reviewer_jwt" in _cm

print("All tests passed! ✓")
