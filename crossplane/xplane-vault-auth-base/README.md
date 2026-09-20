# xplane-vault-auth-base

> **Library module** — not runnable standalone. Exports the `K8sAuth` / `VaultConfig` schemas and the `vaultK8sAuth` function that generate **Crossplane v2 namespaced OpenTofu `Workspace`** resources for Vault Kubernetes auth backends. Imported by consumer modules such as [`xplane-vault-auth`](../xplane-vault-auth/).

- **Workspace apiVersion:** `opentofu.m.upbound.io/v1beta1`
- **Depends on:** [`crossplane-provider-opentofu`](../../models/crossplane-provider-opentofu/)
- **Crossplane:** v2

## API

```python
import xplane_vault_auth_base as vault_auth

config = vault_auth.VaultConfig {
    clusterName = "default"
    vaultAddr = "https://vault.example.com"
    namespace = "default"                        # ns of the Workspace + token Secret
    vaultTokenSecret = "vault"
    providerConfigName = "default"
    providerConfigKind = "ClusterProviderConfig" # or "ProviderConfig"
    k8sAuths = [
        vault_auth.K8sAuth { name = "frontend", tokenPolicies = ["read-secrets"] }
        vault_auth.K8sAuth { name = "backend",  tokenPolicies = ["read-secrets", "write-logs"] }
    ]
}

items = vault_auth.vaultK8sAuth(config)
```

`vaultK8sAuth` returns a flat list of `otf.Workspace` values — one per `k8sAuths` entry — named `<clusterName>-<authName>-vault-auth`, each with an inline HCL module that creates a `vault_auth_backend "kubernetes"` plus its `vault_kubernetes_auth_backend_role`.

### `VaultConfig`

| Field | Default | Notes |
|---|---|---|
| `k8sAuths` | — | List of `K8sAuth` entries. |
| `clusterName` | — | Prefix for auth backend paths. |
| `vaultAddr` | — | Vault server URL. |
| `skipTlsVerify` | `false` | |
| `namespace` | `default` | Namespace of the generated Workspace + `varFiles` Secret. |
| `vaultTokenSecret` | `vault` | Secret name holding `terraform.tfvars`. |
| `vaultTokenSecretKey` | `terraform.tfvars` | Key inside the Secret. |
| `providerConfigName` | `default` | |
| `providerConfigKind` | `ClusterProviderConfig` | Or `ProviderConfig`. |
| `releaseOnDelete` | `false` | Drop `Delete` from the Workspace's `managementPolicies`, so deleting the XR removes the Workspace but leaves the Vault mount, role and policies. For handing them to another owner — see below. |

### `K8sAuth`

| Field | Default |
|---|---|
| `name` | required |
| `clusterName` | required |
| `vaultAddr` | required |
| `skipTlsVerify` | `false` |
| `tokenPolicies` | `["read-secrets"]` |
| `tokenTtl` | `3600` |
| `boundServiceAccountNamespaces` | `["default"]` |
| `labels` / `annotations` | — |

## Vault AppRole Secret

The generated `varFiles` entry references a Secret in the **same namespace** as
the Workspace. Auth is **AppRole**, not a static token — each tofu apply
exchanges `role_id`/`secret_id` for a short-lived Vault token, so the
continuously-reconciling Workspace never wedges on an expired token:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vault
  namespace: default
type: Opaque
stringData:
  terraform.tfvars: |
    vault_role_id   = "..."
    vault_secret_id = "..."
```

The AppRole must be bound to a policy that can manage the kubernetes auth mount
(e.g. `vault-k8sauth-bootstrap`: `sys/auth/*`, `auth/+/config`, `auth/+/role/*`).

## Migration from 0.7.x

0.8.0 is a breaking change:

- Vault provider now authenticates via **AppRole `auth_login`** instead of a
  static `token`. The tfvars Secret must supply `vault_role_id` +
  `vault_secret_id` (was `vault_token`). `skip_child_token = true` is set.
- A `terraform { required_providers }` block now pins vault to `~> 3.25`
  (v5.x reworked `auth_login`); the kubernetes provider (`~> 2.0`) is added only
  when a `backendConfig` is rendered.

## Migration from 0.4.x

0.5.0 was a breaking change:

- Switched dependency from `crossplane-provider-terraform` to `crossplane-provider-opentofu`.
- Workspace `apiVersion` changed to `opentofu.m.upbound.io/v1beta1`.
- `vaultK8sAuth` now returns a **flat** `[Workspace]` (was a list-of-lists; consumers no longer need to flatten).
- `VaultConfig.vaultTokenSecretNamespace` removed — secret is co-located with the Workspace.
- `VaultConfig.namespace` added — namespace of the generated Workspace.
- `VaultConfig.providerConfigName` and `VaultConfig.providerConfigKind` added — consumer must pass a provider config reference; default kind is `ClusterProviderConfig`.
- `providerConfigRef` is emitted by the library; consumers no longer need to inject it.
- `skipTlsVerify` bug fixed (previously an explicit `False` was collapsed to `True`).
- Convenience helpers `simpleVaultK8sAuth`, `simpleVaultK8sAuthWithPolicies`, `advancedVaultK8sAuth`, `multiVaultK8sAuth` removed; call `vaultK8sAuth(VaultConfig{...})` directly.

## License

Apache 2.0 — see [LICENSE](../../LICENSE).

## releaseOnDelete

A Vault mount created here can be taken over by `vault/vault-k8s-auth`, which
drives Vault through provider-vault and holds no state
([crossplane-configurations#482](https://github.com/stuttgart-things/crossplane-configurations/issues/482)).
Adoption leaves both owners holding the same objects, and the OpenTofu side then
has to go **without** a `tofu destroy` — a normal delete would take the mount,
the role and the policies with it, while cert-manager is using them.

```
releaseOnDelete = True   # managementPolicies: ["Observe", "Create", "Update"]
```

The Workspace keeps reconciling until it is deleted; only the destroy is
withheld. The Workspace object still goes away. Its tfstate Secret does not —
remove it once the hand-over is confirmed.

Doing this by hand does not work: `managementPolicies` is owned by Crossplane's
composed-resource field manager, which holds the CRD default and takes the field
back on the next reconcile. It has to come from the composition.
