# flux-infra-cert-manager-selfsigned

Renders the Flux `Kustomization` that adds a self-signed issuer and wildcard certificate on top of cert-manager. Part of the `flux-infra-*` family, which together bootstrap a cluster's
base layer; each module renders exactly one Kustomization.

Published as `ghcr.io/stuttgart-things/flux-infra-cert-manager-selfsigned`.

## Use

```bash
kcl run oci://ghcr.io/stuttgart-things/flux-infra-cert-manager-selfsigned --tag 0.1.0
kcl run . -D cert_manager_selfsigned_domain=example.internal
```

Pin with `--tag`, or `?tag=` in a `function-kcl` `source:`. A `:version` suffix in
the URL path is not a pin -- see [Pinning a module version](../../CLAUDE.md#pinning-a-module-version).

Parameters are read from `-D <key>=<value>` first, then from a `params` dict (so
the module works unchanged as a Crossplane composition step), then the default.

## Parameters

| key | default | |
|---|---|---|
| `name` | `cert-manager-selfsigned` | Kustomization name |
| `namespace` | `flux-system` | where the Kustomization object lives |
| `interval` | `1h` | reconciliation interval |
| `retryInterval` | `1m` | |
| `timeout` | `5m` | |
| `sourceRefName` | `flux-infra` | the Source this Kustomization reads from |
| `sourceRefKind` | `GitRepository` | |
| `path` | `./infra/cert-manager/components/selfsigned` | path inside that Source |
| `cert_manager_namespace` | `cert-manager` | |
| `cert_manager_selfsigned_domain` | `k3s-infra.sthings-vsphere.labul.sva.de` | wildcard domain for the certificate |
| `cert_manager_selfsigned_secret_name` | `wildcard-k3s-infra-tls` | |
| `cert_manager_selfsigned_cert_name` | `wildcard-k3s-infra-tls` | |
| `cert_manager_selfsigned_cert_namespace` | `default` | |
| `cert_manager_selfsigned_issuer` | `vault-pki` | |
| `dependsOnName` | `cert-manager` | |

Everything after `path` is fed to `postBuild.substitute`, so the values land in
the manifests under that path as `${VARIABLE}` replacements.

## Ordering

The rendered Kustomization declares a Flux dependency on `cert-manager` (override with `dependsOnName`), so it is not
applied until that one is ready.

## Layout

```
main.k       renders the Kustomization
templates/   the manifests this Kustomization points at
```
