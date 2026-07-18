# xplane-platform

`function-kcl` module for the
[`platform`](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/platform)
Crossplane Configuration — the umbrella that assembles a cluster's platform from
the bootstrap building blocks.

## What it emits

| Child XR | Configuration | When |
|---|---|---|
| `FluxInit` | [flux-init](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/flux-init) | `spec.fluxInit.enabled` (default true) |
| `FluxApps` | [flux-apps](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/flux-apps) | any enabled entry in `spec.apps` |

Plus the XR status: the resolved `shared` contract and per-component readiness.

## Why it exists

stuttgart-things/flux publishes **one OCI artifact per app**, so a Flux source
name and an app are the same fact. Deploying one by hand means adding an
`OCIRepository` to a `FluxInit` **and** referencing it by name in a `FluxApps` —
two objects, one hand-maintained string, nothing validating it until a
Kustomization stalls.

Here, one toggle produces both:

```yaml
spec:
  clusterName: kind1
  apps:
    dapr:
      components:
        template-execution:
          # requires GITHUB_TOKEN / BACKSTAGE_AUTH_TOKEN / REDIS_PASSWORD —
          # either point at a Secret as here, or set enabled: false
          substituteFrom:
            - kind: Secret
              name: dapr-backstage-template-execution-vars
```

→ an `OCIRepository` named `dapr` on the FluxInit child, **and** a
`dapr-control-plane` + `dapr-template-execution` Kustomization pair on the
FluxApps child, each with `sourceRef: {kind: OCIRepository, name: dapr}` and
`dependsOn` rewritten to the emitted names.

App definitions come from
[`xplane-flux-catalog`](../xplane-flux-catalog/) — structural facts only.

## Layout

```
logic.k        pure functions — every rule, no option("params")
main.k         render entry point: params in, items out
logic_test.k   unit tests (`kcl test`)
```

The split is the point: platform's logic used to be inline in the Composition,
where it could not be tested at all.

## Rules

| Rule | Enforced |
|---|---|
| apps enabled while `fluxInit.enabled: false` | rejected — fluxInit creates the sources apps reference |
| a component depending on a **disabled** sibling | rejected, naming the offenders — it would otherwise sit in `DependencyNotReady` forever |
| unknown app name | rejected by the catalog |
| required substitution variable not supplied | rejected — Flux substitutes empty strings rather than failing, so this would deploy silently broken. Satisfied by `substitute` keys, or skipped when the component carries a `substituteFrom` (resolved at build time, not statically checkable) |
| disabling an app | prunes it — the entry stops being emitted, and flux-apps' Objects use `managementPolicies: ["*"]`, so the Kustomization and its workload are removed |

## Overrides

```yaml
apps:
  dapr:
    version: v1.17.0                    # else catalog defaultVersion
    substitute: {DAPR_NAMESPACE: dapr-system}   # applied to all components
    components:
      control-plane: {enabled: false}
      template-execution:
        substitute: {FLUX_SOURCE_API_VERSION: v1}   # merged, wins
        substituteFrom:
          - kind: Secret
            name: dapr-backstage-template-execution-vars
```

`substituteFrom` is **component-scoped on purpose**. It resolves at *build* time
and a missing Secret fails the build, so an app-level one would break components
that do not need it.

## Gotchas found building this

- KCL does **not** interpolate `${}` inside `assert` messages — it prints the
  placeholder. Concatenate.
- A nested `all` comprehension does not capture the outer loop binding; flatten
  with a list comprehension instead.
- Schema instances must be explicit (`s.Component { ... }`) or a cross-package
  import fails even though in-module tests pass.
