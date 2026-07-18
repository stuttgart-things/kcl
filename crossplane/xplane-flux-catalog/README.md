# xplane-flux-catalog

Structural catalog of the Flux apps published by
[stuttgart-things/flux](https://github.com/stuttgart-things/flux), consumed by the
[`platform`](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/platform)
Configuration to turn a single `spec.apps` toggle into **both** halves of the wiring.

## Why it exists

stuttgart-things/flux publishes **one OCI artifact per app**
(`oci://ghcr.io/stuttgart-things/flux/apps/<name>`), so the Flux source name and the
app are the same fact. Without a catalog, deploying an app means adding an
`OCIRepository` to a `FluxInit` **and** referencing it by name in a `FluxApps` —
a hand-maintained string that nothing validates until a Kustomization stalls.

This module holds the facts needed to generate both from one toggle.

## What it deliberately does NOT hold

Substitution **values** (`DAPR_NAMESPACE`, `DAPR_VERSION`, `DAPR_BACKSTAGE_TPL_*`).
Those are environment-specific, and each app's README in stuttgart-things/flux is
their source of truth — duplicating them here would guarantee drift and force a
catalog release on every environment change. They stay in the XR or a per-cluster
EnvironmentConfig.

## Layout

```
schema.k          App / Component definitions
main.k            the registry: name -> App, plus get(name)
apps/<name>.k     one file per app
catalog_test.k    invariants — run with `kcl test`
```

KCL has no file globbing, so apps are registered explicitly. Adding one is a
two-line diff in `main.k` plus the new file.

## Adding an app

1. `apps/<name>.k` — declare the artifact, default tag and components. Paths are
   relative to the **artifact root** (the artifact *is* the app directory), so
   `./components/control-plane`, not `./apps/<name>/components/control-plane`.
2. Register it in `main.k` (one import, one entry).
3. `kcl test` — the invariants below run automatically.
4. Bump `version` in `kcl.mod`, publish, then bump the pin in platform's
   Composition.

An app is **not** necessarily one Kustomization: dapr ships `control-plane` and
`template-execution`, the second depending on the first.

## Invariants (`kcl test`)

| Test | Catches |
|---|---|
| `test_dependson_targets_exist` | a typo'd `dependsOn` — otherwise found only as a Kustomization stuck in `DependencyNotReady` on a live cluster |
| `test_component_names_unique` | duplicates colliding on the emitted `{app}-{component}` name |
| `test_helmrelease_components_raise_timeout` | a chart-installing component left on the 10m FluxApps default, which is demonstrably too short |

Each was verified to fail on the mistake it describes, not merely to pass.

## Consuming

```python
import xplane_flux_catalog as c

app = c.get("dapr")
app.artifact         # oci://ghcr.io/stuttgart-things/flux/apps/dapr
app.defaultVersion   # v1.18.1
app.components       # [control-plane, template-execution]
```

## Notes

`dapr`'s `template-execution` needs a Secret providing `GITHUB_TOKEN`,
`BACKSTAGE_AUTH_TOKEN` and `REDIS_PASSWORD` in the Kustomization's namespace, via
`substituteFrom`. Deliver it with sops-secrets-operator **before** that component
reconciles — `substituteFrom` resolves at build time, so a Secret applied by the
same Kustomization is too late.

## Consuming from another module

Add it as a `kcl.mod` dependency (the pattern `xplane-platform` uses):

```toml
[dependencies]
xplane-flux-catalog = { oci = "oci://ghcr.io/stuttgart-things/xplane-flux-catalog", tag = "0.1.1" }
```

**Use `0.1.1` or later.** In 0.1.0 the components in `apps/*.k` were plain dict
literals; KCL coerces those inside the module (so `kcl test` passed) but NOT when
the module is imported as a package, where any consumer hit
`expect [xplane_flux_catalog.Component], got list`. App files must instantiate
`s.Component { ... }` explicitly. In-module tests cannot catch this — only an
actual cross-package import can, so verify new app files against a consumer.
