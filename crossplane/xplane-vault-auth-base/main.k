# Library module — not runnable standalone.
# Generates Crossplane v2 namespaced OpenTofu Workspaces that configure
# Vault Kubernetes auth backends.

import crossplane_provider_opentofu.v1beta1 as otf

schema K8sAuth:
    name: str
    clusterName: str
    vaultAddr: str
    skipTlsVerify?: bool = False
    tokenPolicies?: [str] = ["read-secrets"]
    tokenTtl?: int = 3600
    boundServiceAccountNamespaces?: [str] = ["default"]
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

# HCL for a single Vault Kubernetes auth backend + role.
_terraformCode = r"""provider "vault" {
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
  bound_service_account_names      = [var.auth_name]
  bound_service_account_namespaces = var.bound_service_account_namespaces
  token_ttl                        = var.token_ttl
  token_policies                   = var.token_policies
}

variable "auth_name"                        { type = string }
variable "cluster_name"                     { type = string }
variable "vault_addr"                       { type = string }
variable "skip_tls_verify"                  { type = bool   default = false }
variable "vault_token"                      { type = string sensitive = true }
variable "token_policies"                   { type = list(string) default = [] }
variable "token_ttl"                        { type = number default = 3600 }
variable "bound_service_account_namespaces" { type = list(string) default = ["default"] }

output "auth_backend_path" {
  value = vault_auth_backend.kubernetes.path
}

output "auth_role_name" {
  value = vault_kubernetes_auth_backend_role.service_account.role_name
}
"""

_listToJson = lambda items: [str] -> str {
    '["' + '","'.join(items) + '"]'
}

# Build one Workspace for a single K8sAuth entry.
createSingleVaultAuth = lambda auth: K8sAuth, config: VaultConfig -> otf.Workspace {
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
                module = _terraformCode
                inlineFormat = "HCL"
                vars = [
                    {key = "auth_name",        value = auth.name}
                    {key = "cluster_name",     value = auth.clusterName}
                    {key = "vault_addr",       value = auth.vaultAddr}
                    {key = "skip_tls_verify",  value = "true" if auth.skipTlsVerify else "false"}
                    {key = "token_policies",   value = _listToJson(auth.tokenPolicies)}
                    {key = "token_ttl",        value = str(auth.tokenTtl)}
                    {key = "bound_service_account_namespaces", value = _listToJson(auth.boundServiceAccountNamespaces)}
                ]
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
