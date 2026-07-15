# xplane-ip-reservation

`function-kcl` module for the [`ip-reservation`](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/ip-reservation) Crossplane Configuration. Reserves IP addresses from clusterbook using the `internalNetworkKey` discovered from a `RemoteCluster` (provider-kubeconfig).

Consumed from the Composition as an OCI source:

```yaml
- step: ip-reservation
  functionRef:
    name: function-kcl
  input:
    apiVersion: krm.kcl.dev/v1alpha1
    kind: KCLInput
    spec:
      source: oci://ghcr.io/stuttgart-things/xplane-ip-reservation:0.1.0
```

## What it emits

| # | Kind | Purpose | Condition |
|---|------|---------|-----------|
| 1 | `kubernetes.m` Object (Observe) | reads `RemoteCluster.status.internalNetworkKey` | always |
| 2 | `kubernetes.m` Object (wrapper) | `IPReservation` (provider-clusterbook) | once networkKey is known |

Both Objects use the `in-cluster` (InjectedIdentity) provider config — the
cluster-scoped `RemoteCluster` / `IPReservation` MRs are wrapped in namespaced
Objects because the XR is `scope: Namespaced`.

Render and status run in a **single pass**: the module emits both Objects and
patches the XR status from `ocds`. The IPReservation is withheld until the
Observe populates the networkKey, so status converges over reconciles.

## Params

| Param | Source | Notes |
|-------|--------|-------|
| `params.oxr` | the `XIPReservation` XR | `spec.clusterName` required |
| `params.ocds` | observed composed resources | supplies networkKey + IPReservation status |

## Local test

```bash
kcl run main.k -Y test-settings.yaml
```
