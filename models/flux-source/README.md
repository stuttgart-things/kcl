# flux-source

Generated KCL models for the Flux **source-controller** CRDs
(`source.toolkit.fluxcd.io`). Schemas only — there is no runnable entrypoint.

Published as `ghcr.io/stuttgart-things/flux-source`.

## Contents

| package | schemas |
|---|---|
| `v1` | `Bucket`, `ExternalArtifact`, `GitRepository`, `HelmChart`, `HelmRepository`, `OCIRepository` |
| `v1beta2` | `Bucket`, `GitRepository`, `HelmChart`, `OCIRepository` |

`k8s/` holds the vendored `apimachinery` types the schemas reference.

## Use

```toml
# kcl.mod
[dependencies]
flux-source = { oci = "oci://ghcr.io/stuttgart-things/flux-source", tag = "0.0.2", version = "0.0.2" }
```

```python
import flux_source.v1.source_toolkit_fluxcd_io_v1_git_repository as source

repo = source.GitRepository {
    metadata.name = "flux-apps"
    metadata.namespace = "flux-system"
    spec = {
        interval = "1h"
        url = "https://github.com/stuttgart-things/flux-apps"
    }
}
```

## Known issue

This module vendors its own copy of `k8s.apimachinery` under `k8s/`. Consuming it
alongside another module that does the same — `flux-kustomization`, for instance —
fails to compile:

```
the `k8s.apimachinery.pkg.apis.meta.v1` is found multiple times in the
current package and vendor package
```

Declaring `k8s` explicitly in `kcl.mod` does not resolve it. Until the vendored
copy is dropped, the two cannot be used in one package.

## Regenerating

See `crd-sources.md` in the sibling model modules for the CRD sources these are
generated from.
