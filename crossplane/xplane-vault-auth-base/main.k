# Library module — not runnable standalone.
# Generates Crossplane v2 namespaced OpenTofu Workspaces that configure
# Vault Kubernetes auth backends (optionally with backend_config).

import v1beta1 as otf

schema K8sAuthBackendConfig:
    # Renders a `vault_kubernetes_auth_backend_config` for this auth. The
    # resource's CA cert and token reviewer JWT are read at tofu-apply time
    # via the kubernetes TF provider `data "kubernetes_secret"` from a
    # Secret in the cluster running opentofu-provider.
    secretName: str
    secretNamespace?: str   # defaults to the Workspace namespace
    caCertKey?: str = "ca.crt"
    tokenKey?: str = "token"
    disableIssValidation?: bool = True
    disableLocalCaJwt?: bool = True

schema K8sAuth:
    name: str
    clusterName: str
    vaultAddr: str
    skipTlsVerify?: bool = False
    tokenPolicies?: [str] = ["read-secrets"]
    tokenTtl?: int = 3600
    boundServiceAccountNames?: [str] = ["default"]
    boundServiceAccountNamespaces?: [str] = ["default"]
    # If set, the generated Workspace also renders vault_kubernetes_auth_backend_config.
    backendConfig?: K8sAuthBackendConfig
    labels?: {str: str}
    annotations?: {str: str}

schema VaultConfig:
    k8sAuths: [K8sAuth]
    clusterName: str
    vaultAddr: str
    skipTlsVerify?: bool = False
    namespace?: str = "default"
    vaultTokenSecret?: str = "vault"
    vaultTokenSecretKey?: str = "terraform.tfvars"
    providerConfigName?: str = "default"
    providerConfigKind?: "ClusterProviderConfig" | "ProviderConfig" = "ClusterProviderConfig"
    # Required if any K8sAuth in k8sAuths has backendConfig set.
    kubernetesHost?: str

# Base HCL: vault provider + auth_backend + auth_backend_role.
_baseHcl = r"""provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = var.skip_tls_verify
  token           = var.vault_token
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "${var.cluster_name}-${var.auth_name}"
}

resource "vault_kubernetes_auth_backend_role" "service_account" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.auth_name
  bound_service_account_names      = var.bound_service_account_names
  bound_service_account_namespaces = var.bound_service_account_namespaces
  token_ttl                        = var.token_ttl
  token_policies                   = var.token_policies
}

variable "auth_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vault_addr" {
  type = string
}

variable "skip_tls_verify" {
  type    = bool
  default = false
}

variable "vault_token" {
  type      = string
  sensitive = true
}

variable "token_policies" {
  type    = list(string)
  default = []
}

variable "token_ttl" {
  type    = number
  default = 3600
}

variable "bound_service_account_names" {
  type    = list(string)
  default = ["default"]
}

variable "bound_service_account_namespaces" {
  type    = list(string)
  default = ["default"]
}

output "auth_backend_path" {
  value = vault_auth_backend.kubernetes.path
}

output "auth_role_name" {
  value = vault_kubernetes_auth_backend_role.service_account.role_name
}
"""

# Optional HCL: kubernetes provider + SA secret data source + backend_config.
_backendConfigHcl = r"""
provider "kubernetes" {}

data "kubernetes_secret" "sa" {
  metadata {
    name      = var.sa_secret_name
    namespace = var.sa_secret_namespace
  }
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  kubernetes_ca_cert     = data.kubernetes_secret.sa.data[var.sa_ca_cert_key]
  token_reviewer_jwt     = data.kubernetes_secret.sa.data[var.sa_token_key]
  disable_iss_validation = var.disable_iss_validation
  disable_local_ca_jwt   = var.disable_local_ca_jwt

  depends_on = [vault_auth_backend.kubernetes]
}

variable "kubernetes_host" {
  type = string
}

variable "sa_secret_name" {
  type = string
}

variable "sa_secret_namespace" {
  type = string
}

variable "sa_ca_cert_key" {
  type    = string
  default = "ca.crt"
}

variable "sa_token_key" {
  type    = string
  default = "token"
}

variable "disable_iss_validation" {
  type    = bool
  default = true
}

variable "disable_local_ca_jwt" {
  type    = bool
  default = true
}
"""

_listToJson = lambda items: [str] -> str {
    '["' + '","'.join(items) + '"]'
}

_baseVars = lambda auth: K8sAuth -> [{str:str}] {
    [
        {key = "auth_name",                         value = auth.name}
        {key = "cluster_name",                      value = auth.clusterName}
        {key = "vault_addr",                        value = auth.vaultAddr}
        {key = "skip_tls_verify",                   value = "true" if auth.skipTlsVerify else "false"}
        {key = "token_policies",                    value = _listToJson(auth.tokenPolicies)}
        {key = "token_ttl",                         value = str(auth.tokenTtl)}
        {key = "bound_service_account_names",       value = _listToJson(auth.boundServiceAccountNames)}
        {key = "bound_service_account_namespaces",  value = _listToJson(auth.boundServiceAccountNamespaces)}
    ]
}

_backendConfigVars = lambda auth: K8sAuth, config: VaultConfig -> [{str:str}] {
    bc = auth.backendConfig
    [
        {key = "kubernetes_host",        value = config.kubernetesHost or ""}
        {key = "sa_secret_name",         value = bc.secretName}
        {key = "sa_secret_namespace",    value = bc.secretNamespace or config.namespace}
        {key = "sa_ca_cert_key",         value = bc.caCertKey}
        {key = "sa_token_key",           value = bc.tokenKey}
        {key = "disable_iss_validation", value = "true" if bc.disableIssValidation else "false"}
        {key = "disable_local_ca_jwt",   value = "true" if bc.disableLocalCaJwt else "false"}
    ] if bc else []
}

# Build one Workspace for a single K8sAuth entry.
createSingleVaultAuth = lambda auth: K8sAuth, config: VaultConfig -> otf.Workspace {
    _module = _baseHcl + (_backendConfigHcl if auth.backendConfig else "")
    _vars = _baseVars(auth) + _backendConfigVars(auth, config)
    otf.Workspace {
        metadata = {
            name = "{}-{}-vault-auth".format(auth.clusterName, auth.name)
            namespace = config.namespace
            labels = auth.labels
            annotations = auth.annotations
        }
        spec = {
            providerConfigRef = {
                name = config.providerConfigName
                kind = config.providerConfigKind
            }
            forProvider = {
                source = "Inline"
                module = _module
                inlineFormat = "HCL"
                vars = _vars
                varFiles = [{
                    source = "SecretKey"
                    format = "HCL"
                    secretKeyRef = {
                        name = config.vaultTokenSecret
                        key = config.vaultTokenSecretKey
                    }
                }]
            }
        }
    }
}

# Main function — returns a flat list of Workspaces.
vaultK8sAuth = lambda config: VaultConfig -> [otf.Workspace] {
    [createSingleVaultAuth(auth, config) for auth in config.k8sAuths]
}
