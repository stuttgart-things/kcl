# Library module — not runnable standalone.
# Generates Crossplane v2 namespaced OpenTofu Workspaces that configure
# Vault Kubernetes auth backends (optionally with backend_config).
import regex
import json
import v1beta1 as otf

schema K8sAuthBackendConfig:
    # Renders a `vault_kubernetes_auth_backend_config` for this auth. The
    # resource's CA cert and token reviewer JWT are read at tofu-apply time
    # via the kubernetes TF provider `data "kubernetes_secret"` from a
    # Secret in the cluster running opentofu-provider.
    secretName: str
    # defaults to the Workspace namespace
    secretNamespace?: str
    caCertKey?: str = "ca.crt"
    tokenKey?: str = "token"
    disableIssValidation?: bool = True
    disableLocalCaJwt?: bool = True

schema VaultPolicy:
    """One Vault ACL policy, created for the auth that declares it.

    The body is BUILT here, from a bounded description — it is deliberately not
    accepted as HCL. A free-form body plus the ability to bind it to your own
    role is the right to grant yourself anything: a cluster could write
    `path "clusters/*" { capabilities = ["read"] }` and read every other
    cluster's secrets. Restricting the policy NAME does not help, because Vault
    cannot restrict what a policy body contains — so the body has to come from
    here. See crossplane-configurations#285.

    What remains configurable is the part that is safe to configure: which KV
    mount, and which subtrees of it. Not the paths, not the capabilities, not
    the mount type — nothing that could name `sys/`, `auth/`, or `sudo`.
    """
    name: str
    """Suffix. The policy is named `{clusterName}-{name}`, so two clusters
    granting the same kind of access do not collide on one object."""

    kvMount: str
    """The KV v2 mount the grants apply to, e.g. `clusters`. One mount per
    policy: a grant that spans mounts is two grants with two lifetimes."""

    read: [str]
    """Subtrees of kvMount to grant read on. The literal `own` expands to this
    cluster's own subtree — a cluster cannot spell another cluster's name into
    that position and get it, because `own` is the only value that resolves to a
    cluster name.

    A LIST because one cluster rarely wants one subtree: its own, plus whatever
    a role it plays grants it — a cluster with the cicd profile reads the cicd
    tree as well as its own.
    """

    check:
        len(name) > 0, "a policy needs a name"
        len(kvMount) > 0, "a policy needs the KV mount its grants apply to"
        len(read) > 0, "a policy that grants no read grants nothing and hides that it does"
        all s in read {regex.match(s, r"^[a-z0-9][a-z0-9._-]*$")}, "a subtree is a plain name, not a path — no slashes, no globs, no traversal"

schema K8sAuth:
    name: str
    clusterName: str
    vaultAddr: str
    skipTlsVerify?: bool = False
    tokenPolicies?: [str] = ["read-secrets"]
    tokenTtl?: int = 3600
    boundServiceAccountNames?: [str] = ["default"]
    boundServiceAccountNamespaces?: [str] = ["default"]
    policies?: [VaultPolicy] = []
    """Vault policies to CREATE for this auth, each named `{clusterName}-{name}`
    and appended to tokenPolicies.

    A LIST because one cluster rarely wants one policy: its own KV subtree, plus
    whatever a role it plays grants it — a cluster with the cicd profile reads
    the cicd tree as well as its own. Those are separate grants with separate
    lifetimes, not one policy with a longer body.

    Vault accepts a role that names a policy which does not exist — the token
    then simply has no permissions, with no error anywhere. Creating them beside
    the role, in the same plan, is what removes that: tofu orders them by the
    reference, and a destroy reverses it.

    The names are derived rather than passed, so a caller can neither repeat nor
    misspell them. Leave empty to keep referencing policies that already exist
    in Vault, via tokenPolicies.
    """

    backendConfig?: K8sAuthBackendConfig
    labels?: {str:str}
    annotations?: {str:str}

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

# Base HCL: vault provider (AppRole login) + auth_backend + auth_backend_role.
#
# Auth is AppRole, NOT a static token: each tofu apply exchanges
# role_id/secret_id for a short-lived Vault token carrying only the
# vault-k8sauth-bootstrap policy. This is why the continuously-reconciling
# Workspace no longer wedges — a static token expires (768h cap) and 403s every
# reconcile in both create and delete; an AppRole login mints a fresh token each
# run. role_id/secret_id arrive via the tfvars varFile (SecretKey), same slot
# the old static vault_token used.
#
# skip_child_token = true: the provider would otherwise mint a child token via
# auth/token/create, which the least-privilege bootstrap policy need not allow.
# Pin vault ~> 3.25: v5.x reworked the auth_login block ("Blocks of type
# auth_login are not expected here").
_baseHcl = r"""provider "vault" {
  address          = var.vault_addr
  skip_tls_verify  = var.skip_tls_verify
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "${var.cluster_name}-${var.auth_name}"
}

# Empty map when no policies were declared, so a caller that only references
# existing ones gets a plan identical to before.
resource "vault_policy" "auth" {
  for_each = var.policies
  name     = "${var.cluster_name}-${each.key}"
  policy   = each.value
}

resource "vault_kubernetes_auth_backend_role" "service_account" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.auth_name
  bound_service_account_names      = var.bound_service_account_names
  bound_service_account_namespaces = var.bound_service_account_namespaces
  token_ttl                        = var.token_ttl
  # The reference is what orders the two: tofu creates the policy before the
  # role that names it, and destroys them in the reverse order. Splitting this
  # across two systems is what makes "role bound to a policy that is not there
  # yet" possible, and Vault reports that as nothing at all.
  token_policies                   = concat(var.token_policies, [for p in vault_policy.auth : p.name])
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

variable "vault_role_id" {
  type      = string
  sensitive = true
}

variable "vault_secret_id" {
  type      = string
  sensitive = true
}

variable "token_policies" {
  type    = list(string)
  default = []
}

variable "policies" {
  type    = map(string)
  default = {}
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

output "policy_names" {
  value = [for p in vault_policy.auth : p.name]
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

# required_providers: pin vault to ~> 3.25 (v5 reworked auth_login). Add the
# kubernetes provider only when a backend_config is rendered (it reads the
# reviewer JWT / CA via data "kubernetes_secret").
_terraformBlock = lambda hasBackendConfig: bool -> str {
    _k8s = '\n    kubernetes = {\n      source  = "hashicorp/kubernetes"\n      version = "~> 2.0"\n    }' if hasBackendConfig else ""
    'terraform {\n  required_providers {\n    vault = {\n      source  = "hashicorp/vault"\n      version = "~> 3.25"\n    }' + _k8s + '\n  }\n}\n\n'
}

# The policy body is built HERE and nowhere else — see VaultPolicy for why it
# is not accepted as HCL. Every path is anchored at "{mount}/data/" or
# "{mount}/metadata/", every capability list is a literal, and the only value
# that ever reaches a path is a subtree name the schema has already constrained
# to [a-z0-9._-]. There is no input that can widen this beyond read on one KV
# mount.
#
# metadata gets list as well as read: without it `vault kv list` and the ESO
# `find` selector fail on a tree the token can otherwise read, which reads like
# a missing secret rather than a missing capability.
_policyBody = lambda clusterName: str, policy: VaultPolicy -> str {
    _subtree = lambda scope: str -> str {
        clusterName if scope == "own" else scope
    }

    # FOUR paths per subtree, not two. Vault matches a policy path exactly
    # unless it ends in a glob, and `x/data/default/*` does NOT match
    # `x/data/default` — so a secret that IS the subtree (the cicd mounts put
    # theirs directly under the mount, at cicd-proxmox-labul/data/default) was
    # denied by a policy that appeared to grant it. Measured on u26-rke2-1:
    # external-secrets logged 403 on exactly that path while the
    # ClusterSecretStore reported Valid, so the login worked and only the read
    # failed.
    "\n".join(sum([[
        'path "' + policy.kvMount + '/data/' + _subtree(s) + '" { capabilities = ["read"] }'
        'path "' + policy.kvMount + '/data/' + _subtree(s) + '/*" { capabilities = ["read"] }'
        'path "' + policy.kvMount + '/metadata/' + _subtree(s) + '" { capabilities = ["read", "list"] }'
        'path "' + policy.kvMount + '/metadata/' + _subtree(s) + '/*" { capabilities = ["read", "list"] }'
    ] for s in policy.read], [])) + "\n"
}

_listToJson = lambda items: [str] -> str {
    '["' + '","'.join(items) + '"]'
}

_baseVars = lambda auth: K8sAuth -> [{str:str}] {
    [
        {key = "auth_name", value = auth.name}
        {key = "cluster_name", value = auth.clusterName}
        {key = "vault_addr", value = auth.vaultAddr}
        {key = "skip_tls_verify", value = "true" if auth.skipTlsVerify else "false"}
        {key = "token_policies", value = _listToJson(auth.tokenPolicies)}
        {key = "token_ttl", value = str(auth.tokenTtl)}
        {key = "bound_service_account_names", value = _listToJson(auth.boundServiceAccountNames)}
        {key = "bound_service_account_namespaces", value = _listToJson(auth.boundServiceAccountNamespaces)}
        {key = "policies", value = json.encode({p.name: _policyBody(auth.clusterName, p) for p in (auth.policies or [])})}
    ]
}

_backendConfigVars = lambda auth: K8sAuth, config: VaultConfig -> [{str:str}] {
    bc = auth.backendConfig
    [
        {key = "kubernetes_host", value = config.kubernetesHost or ""}
        {key = "sa_secret_name", value = bc.secretName}
        {key = "sa_secret_namespace", value = bc.secretNamespace or config.namespace}
        {key = "sa_ca_cert_key", value = bc.caCertKey}
        {key = "sa_token_key", value = bc.tokenKey}
        {key = "disable_iss_validation", value = "true" if bc.disableIssValidation else "false"}
        {key = "disable_local_ca_jwt", value = "true" if bc.disableLocalCaJwt else "false"}
    ] if bc else []
}

# Build one Workspace for a single K8sAuth entry.
createSingleVaultAuth = lambda auth: K8sAuth, config: VaultConfig -> otf.Workspace {
    _module = _terraformBlock(auth.backendConfig != Undefined) + _baseHcl + (_backendConfigHcl if auth.backendConfig else "")
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
