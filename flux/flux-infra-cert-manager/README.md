# flux-infra-cert-manager

Renders the Flux `Kustomization` that installs cert-manager. Part of the `flux-infra-*` family, which together bootstrap a cluster's
base layer; each module renders exactly one Kustomization.

Published as `ghcr.io/stuttgart-things/flux-infra-cert-manager`.

## Use

```bash
kcl run oci://ghcr.io/stuttgart-things/flux-infra-cert-manager --tag 0.1.0
kcl run . -D cert_manager_version=v1.18.2
```

Pin with `--tag`, or `?tag=` in a `function-kcl` `source:`. A `:version` suffix in
the URL path is not a pin -- see [Pinning a module version](../../CLAUDE.md#pinning-a-module-version).

Parameters are read from `-D <key>=<value>` first, then from a `params` dict (so
the module works unchanged as a Crossplane composition step), then the default.

## Parameters

| key | default | |
|---|---|---|
| `name` | `cert-manager` | Kustomization name |
| `namespace` | `flux-system` | where the Kustomization object lives |
| `interval` | `1h` | reconciliation interval |
| `retryInterval` | `1m` | |
| `timeout` | `5m` | |
| `sourceRefName` | `flux-infra` | the Source this Kustomization reads from |
| `sourceRefKind` | `GitRepository` | |
| `path` | `./infra/cert-manager/components/install` | path inside that Source |
| `cert_manager_namespace` | `cert-manager` | substituted into the manifests |
| `cert_manager_version` | `v1.18.2` | substituted into the manifests |

Everything after `path` is fed to `postBuild.substitute`, so the values land in
the manifests under that path as `${VARIABLE}` replacements.

## Layout

```
main.k       renders the Kustomization
templates/   the manifests this Kustomization points at
```
