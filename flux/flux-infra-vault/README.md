# flux-infra-vault

Renders the Flux `Kustomization` that deploys HashiCorp Vault and exposes it through the Cilium gateway. Part of the `flux-infra-*` family, which together bootstrap a cluster's
base layer; each module renders exactly one Kustomization.

Published as `ghcr.io/stuttgart-things/flux-infra-vault`.

## Use

```bash
kcl run oci://ghcr.io/stuttgart-things/flux-infra-vault --tag 0.1.0
kcl run . -D vault_domain=example.internal
```

Pin with `--tag`, or `?tag=` in a `function-kcl` `source:`. A `:version` suffix in
the URL path is not a pin -- see [Pinning a module version](../../CLAUDE.md#pinning-a-module-version).

Parameters are read from `-D <key>=<value>` first, then from a `params` dict (so
the module works unchanged as a Crossplane composition step), then the default.

## Parameters

| key | default | |
|---|---|---|
| `name` | `vault` | Kustomization name |
| `namespace` | `flux-system` | where the Kustomization object lives |
| `interval` | `1h` | reconciliation interval |
| `retryInterval` | `1m` | |
| `timeout` | `10m` | |
| `sourceRefName` | `flux-infra` | the Source this Kustomization reads from |
| `sourceRefKind` | `GitRepository` | |
| `path` | `./infra/vault` | path inside that Source |
| `vault_namespace` | `vault` | |
| `vault_version` | `1.9.0` | |
| `storage_class` | `local-path` | PVC storage class |
| `gateway_name` | `k3s-infra-gateway` | gateway the HTTPRoute attaches to |
| `gateway_namespace` | `default` | |
| `vault_hostname` | `vault` | host part of the external URL |
| `vault_domain` | `k3s-infra.sthings-vsphere.labul.sva.de` | domain part |
| `dependsOnName` | `cilium-gateway` | |

Everything after `path` is fed to `postBuild.substitute`, so the values land in
the manifests under that path as `${VARIABLE}` replacements.

## Ordering

The rendered Kustomization declares a Flux dependency on `cilium-gateway` (override with `dependsOnName`), so it is not
applied until that one is ready.

## Layout

```
main.k       renders the Kustomization
templates/   the manifests this Kustomization points at
```
