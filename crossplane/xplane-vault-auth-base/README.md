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

## Vault token Secret

The generated `varFiles` entry references a Secret in the **same namespace** as the Workspace:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vault
  namespace: default
type: Opaque
stringData:
  terraform.tfvars: |
    vault_token = "hvs..."
```

## Migration from 0.4.x

0.5.0 is a breaking change:

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
