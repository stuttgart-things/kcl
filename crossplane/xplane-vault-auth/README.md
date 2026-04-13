# xplane-vault-auth

Generates Crossplane v2 namespaced **OpenTofu** `Workspace` resources that configure Vault Kubernetes auth backends. Thin wrapper around [`xplane-vault-auth-base`](../xplane-vault-auth-base/).

- **Workspace apiVersion:** `opentofu.m.upbound.io/v1beta1`
- **Provider:** [`upbound/provider-opentofu`](https://github.com/upbound/provider-opentofu) (namespaced variant)
- **Crossplane:** v2 (namespaced managed resources)

## Create the Vault token secret

The generated Workspace expects a Secret co-located in the **same namespace** as the Workspace itself (v2 no longer allows cross-namespace `secretKeyRef`).

```bash
cat > terraform.tfvars <<EOF
vault_token = "your-vault-token-here"
EOF

kubectl create secret generic vault \
  -n default \
  --from-file=terraform.tfvars=terraform.tfvars

rm terraform.tfvars
```

## Render

```bash
kcl run --quiet oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.2.0 \
  -D params='{
    "oxr": {
      "spec": {
        "clusterName": "default",
        "namespace": "default",
        "vaultAddr": "https://vault.example.com",
        "providerConfigName": "default",
        "providerConfigKind": "ClusterProviderConfig",
        "vaultTokenSecret": "vault",
        "k8sAuths": [
          {"name": "frontend", "tokenPolicies": ["read-secrets"]},
          {"name": "backend",  "tokenPolicies": ["read-secrets","write-logs"]}
        ]
      }
    }
  }' --format yaml \
  | yq eval -P '.items[]' - \
  | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}'
```

## Parameters (`oxr.spec`)

| Field | Default | Notes |
|---|---|---|
| `clusterName` | `default` | Prefix for auth backend paths (`<cluster>-<auth>`). |
| `namespace` | `default` | Namespace for the generated Workspace CRs and the token Secret. |
| `vaultAddr` | `https://vault.example.com` | |
| `skipTlsVerify` | `true` | Applied per-auth unless overridden on the entry. |
| `vaultTokenSecret` | `vault` | Name of the Secret holding `terraform.tfvars` with `vault_token = "..."`. |
| `vaultTokenSecretKey` | `terraform.tfvars` | |
| `providerConfigName` | `<clusterName>` | |
| `providerConfigKind` | `ClusterProviderConfig` | Or `ProviderConfig` for a namespaced config. |
| `k8sAuths[]` | `frontend`, `backend` demo | See below. |

### `k8sAuths[]` entry

| Field | Default |
|---|---|
| `name` | required |
| `tokenPolicies` | `["read-secrets"]` |
| `tokenTtl` | `3600` |
| `boundServiceAccountNamespaces` | `["default"]` |
| `skipTlsVerify` | inherits from top-level |

Each entry renders one `Workspace` named `<clusterName>-<name>-vault-auth` with an inline HCL module that creates `vault_auth_backend` + `vault_kubernetes_auth_backend_role`.
