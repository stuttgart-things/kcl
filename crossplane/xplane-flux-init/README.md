# xplane-flux-init

`function-kcl` module for the [`flux-init`](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/flux-init) Crossplane Configuration. Bootstraps [Flux](https://fluxcd.io/) on a target cluster via the [flux-operator](https://github.com/controlplaneio-fluxcd/flux-operator).

Consumed from the Composition as an OCI source:

```yaml
- step: flux-init
  functionRef:
    name: function-kcl
  input:
    apiVersion: krm.kcl.dev/v1alpha1
    kind: KCLInput
    spec:
      source: oci://ghcr.io/stuttgart-things/xplane-flux-init:0.1.0
```

## What it emits

| # | Kind | Purpose | Condition |
|---|------|---------|-----------|
| 1 | `helm.m.crossplane.io/v1beta1` Release | flux-operator chart | always |
| 2 | `kubernetes.m.crossplane.io/v1alpha1` Object | `FluxInstance` CR (`uses` operator) | always |
| 3 | `protection.crossplane.io/v1beta1` Usage | FluxInstance deletes before operator | always |
| 4..N | `kubernetes.m.crossplane.io/v1alpha1` Object | `OCIRepository`/`GitRepository` CR | per `spec.instance.sources` entry |

Render and status run in a **single pass**: the module emits the managed
resources and, in the same `items` list, patches the XR `status` from `ocds`
(observed composed resources). On the first reconcile `ocds` is empty, so
`status.ready` starts `false` and converges as the composed resources become
Ready.

## Params

| Param | Source | Notes |
|-------|--------|-------|
| `params.oxr` | the `FluxInit` XR | `spec.helmProviderConfigRef` / `kubernetesProviderConfigRef` required |
| `params.ocds` | observed composed resources | drives `status.*Ready` |
| `params.ctx["apiextensions.crossplane.io/environment"]` | `flux-defaults` EnvironmentConfig | supplies chart version, distribution, components, reconcile intervals |

**Precedence:** `spec.*` > EnvironmentConfig > hardcoded fallback.

## Local test

```bash
kcl run main.k -Y test-settings.yaml
```

`test-settings.yaml` mocks `params.oxr` / `params.ocds` / `params.ctx` the way
`function-kcl` supplies them at render time.
