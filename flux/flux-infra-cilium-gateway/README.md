# flux-infra-cilium-gateway

Renders the Flux `Kustomization` that configures the Cilium Gateway API resources. Part of the `flux-infra-*` family, which together bootstrap a cluster's
base layer; each module renders exactly one Kustomization.

Published as `ghcr.io/stuttgart-things/flux-infra-cilium-gateway`.

## Use

```bash
kcl run oci://ghcr.io/stuttgart-things/flux-infra-cilium-gateway --tag 0.1.0
kcl run . -D cilium_gateway_domain=example.internal
```

Pin with `--tag`, or `?tag=` in a `function-kcl` `source:`. A `:version` suffix in
the URL path is not a pin -- see [Pinning a module version](../../CLAUDE.md#pinning-a-module-version).

Parameters are read from `-D <key>=<value>` first, then from a `params` dict (so
the module works unchanged as a Crossplane composition step), then the default.

## Parameters

| key | default | |
|---|---|---|
| `name` | `cilium-gateway` | Kustomization name |
| `namespace` | `flux-system` | where the Kustomization object lives |
| `interval` | `1h` | reconciliation interval |
| `retryInterval` | `1m` | |
| `timeout` | `5m` | |
| `sourceRefName` | `flux-infra` | the Source this Kustomization reads from |
| `sourceRefKind` | `GitRepository` | |
| `path` | `./infra/cilium/components/gateway` | path inside that Source |
| `cilium_gateway_name` | `k3s-infra-gateway` | |
| `cilium_gateway_namespace` | `default` | |
| `cilium_gateway_domain` | `k3s-infra.sthings-vsphere.labul.sva.de` | |
| `cilium_gateway_tls_secret` | `wildcard-k3s-infra-tls` | the certificate the gateway terminates with |
| `dependsOnNames` | `cilium-lb,cert-manager-selfsigned` | comma-separated, split into a `dependsOn` list |

Everything after `path` is fed to `postBuild.substitute`, so the values land in
the manifests under that path as `${VARIABLE}` replacements.

## Ordering

The rendered Kustomization declares a Flux dependency on `cilium-lb` and `cert-manager-selfsigned` (override with `dependsOnNames`, comma-separated), so it is not
applied until that one is ready.

## Layout

```
main.k       renders the Kustomization
templates/   the manifests this Kustomization points at
```
