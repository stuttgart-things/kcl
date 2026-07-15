# xplane-flux-apps

`function-kcl` module for the [`flux-apps`](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/flux-apps)
Crossplane Configuration.

Generic app deployment for Flux. Given a namespaced `FluxApps` XR that carries a
list of apps, this module emits **one `kubernetes.m.crossplane.io/v1alpha1`
Object per app**, each wrapping a `kustomize.toolkit.fluxcd.io/v1` Kustomization
applied to a target cluster via a Kubernetes `ClusterProviderConfig`.

It is the data-driven generalization of the
[`flux-app-kustomizations`](../../flux/flux-app-kustomizations) module: the
hardcoded `tekton` / `crossplane` Kustomizations there become entries in
`spec.apps` here, so new apps are added as data, not code.

Each Kustomization references an **existing** Flux source
(`GitRepository` / `OCIRepository` / `Bucket`) — the source is a precondition on
the target cluster, typically bootstrapped by the
[`flux-init`](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/flux-init)
Configuration.

## Inputs (`option("params")`)

| Field | Meaning |
|---|---|
| `oxr` | The observed `FluxApps` XR (spec + metadata). |
| `ocds` | Observed composed resources — read to compute `status`. |
| `ctx["apiextensions.crossplane.io/environment"]` | Defaults from the `flux-apps-defaults` EnvironmentConfig. |

Value resolution is **spec > EnvironmentConfig > hardcoded fallback** for the
shared fields (`namespace`, `interval`, `retryInterval`, `timeout`,
`sourceRef`); per-app fields under `spec.apps[]` always win.

## Outputs

- One `Object` (namespaced provider-kubernetes) per `spec.apps` entry, wrapping
  a Flux `Kustomization` named after the app.
- The XR with `status` patched (`ready`, `appsReady`, `appCount`, `readyCount`).

## Render locally

```bash
kcl run -Y test-settings.yaml
```

## Push

```bash
kcl mod push oci://ghcr.io/stuttgart-things/xplane-flux-apps
```
