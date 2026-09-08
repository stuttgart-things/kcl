# flux-helmrelease

KCL module that renders Flux [`HelmRelease`](https://fluxcd.io/flux/components/helm/helmreleases/)
resources (`helm.toolkit.fluxcd.io/v2`) from a simplified schema, so callers do
not have to spell out the full CRD every time.

Published as `ghcr.io/stuttgart-things/flux-helmrelease`.

## Use as a dependency

```toml
# kcl.mod
[dependencies]
flux-helmrelease = { oci = "oci://ghcr.io/stuttgart-things/flux-helmrelease", tag = "0.1.0" }
```

Pin with `tag`. A `:version` suffix in the URL path is not a pin — see
[Pinning a module version](../../CLAUDE.md#pinning-a-module-version).

## Helpers

| function | use |
|---|---|
| `helmReleaseFromRepo(name, chartName, chartVersion, repoName, values = {})` | chart from a `HelmRepository` |
| `helmReleaseFromGit(name, chartPath, gitRepoName, values = {})` | chart from a path inside a `GitRepository` |
| `generateHelmRelease(config: SimpleHelmRelease)` | full control via the schema below |
| `generateCrossplaneHelmRelease()` | read the fields off a Crossplane XR spec |

Each returns `[helm.HelmRelease]` — a list, so the result drops straight into a
composition's `items`.

```python
import flux_helmrelease.main as flux

items = flux.helmReleaseFromRepo("nginx", "nginx", "15.0.0", "bitnami", {
    replicaCount = 3
})
```

## `SimpleHelmRelease`

| field | default | |
|---|---|---|
| `name` | — | required |
| `chart` | — | required, `ChartRef` |
| `namespace` | `flux-system` | where the HelmRelease itself lives |
| `interval` | `5m` | reconciliation interval |
| `timeout` | `5m` | |
| `suspend` | `False` | |
| `values` | — | Helm values overriding chart defaults |
| `targetNamespace` | — | where the release is installed |
| `releaseName` | `name` | |
| `storageNamespace` | — | |
| `dependsOn` | — | `[DependencyRef]` that must be ready first |
| `install` / `upgrade` | — | `InstallConfig` / `UpgradeConfig` |
| `labels` / `annotations` | — | |

Supporting schemas: `ChartRef`, `SourceRef`, `DependencyRef`, `InstallConfig`,
`UpgradeConfig`, `RemediationConfig`.

## Use from a Crossplane composition

`generateCrossplaneHelmRelease()` takes no arguments and reads the XR spec
instead: `name`, `chartName`, `chartVersion`, `sourceKind` (`HelmRepository`,
`GitRepository` or `OCIRepository`), `sourceName`, `sourceNamespace`,
`namespace`, `interval`, `values`, `targetNamespace`, `releaseName` and
`createNamespace`. Only `chartName` and `sourceName` carry no usable default.

```yaml
spec:
  name: nginx
  chartName: nginx
  chartVersion: "15.0.0"
  sourceKind: HelmRepository
  sourceName: bitnami
  targetNamespace: production
  values:
    replicaCount: 3
```

## Layout

```
main.k          schemas and helpers (the module's API)
simple_test.k   unit tests -- `kcl test ./...`
examples/       standalone usage snippets, not compiled with the module
v2/, v2beta2/   generated Flux HelmRelease CRD models
crd-sources.md  where the generated models come from
```

`kcl run .` renders `generateCrossplaneHelmRelease()` with its defaults, which
is what CI uses as a smoke test.
