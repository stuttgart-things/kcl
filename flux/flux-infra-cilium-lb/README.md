# flux-infra-cilium-lb

Renders the Flux `Kustomization` that defines the Cilium LoadBalancer IP pool. Part of the `flux-infra-*` family, which together bootstrap a cluster's
base layer; each module renders exactly one Kustomization.

Published as `ghcr.io/stuttgart-things/flux-infra-cilium-lb`.

## Use

```bash
kcl run oci://ghcr.io/stuttgart-things/flux-infra-cilium-lb --tag 0.1.0
kcl run . -D cilium_lb_ip_start=10.31.103.12 -D cilium_lb_ip_stop=10.31.103.13
```

Pin with `--tag`, or `?tag=` in a `function-kcl` `source:`. A `:version` suffix in
the URL path is not a pin -- see [Pinning a module version](../../CLAUDE.md#pinning-a-module-version).

Parameters are read from `-D <key>=<value>` first, then from a `params` dict (so
the module works unchanged as a Crossplane composition step), then the default.

## Parameters

| key | default | |
|---|---|---|
| `name` | `cilium-lb` | Kustomization name |
| `namespace` | `flux-system` | where the Kustomization object lives |
| `interval` | `1h` | reconciliation interval |
| `retryInterval` | `1m` | |
| `timeout` | `5m` | |
| `sourceRefName` | `flux-infra` | the Source this Kustomization reads from |
| `sourceRefKind` | `GitRepository` | |
| `path` | `./infra/cilium/components/lb` | path inside that Source |
| `cilium_lb_ip_start` | `10.31.103.12` | first address of the pool |
| `cilium_lb_ip_stop` | `10.31.103.13` | last address of the pool |

Everything after `path` is fed to `postBuild.substitute`, so the values land in
the manifests under that path as `${VARIABLE}` replacements.

## Layout

```
main.k       renders the Kustomization
templates/   the manifests this Kustomization points at
```
