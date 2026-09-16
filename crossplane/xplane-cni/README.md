# xplane-cni

`function-kcl` module behind the [`cni`](https://github.com/stuttgart-things/crossplane-configurations/tree/main/bootstrap/cni)
Crossplane Configuration. Installs a CNI on a target cluster and reports when it
is up.

```
Cni XR
 ├─ kubernetes.m.crossplane.io Object   RemoteCluster (Observe) — gate
 ├─ helm.m.crossplane.io Release        Gateway API CRDs (opt-in, installed FIRST)
 └─ helm.m.crossplane.io Release        the CNI chart (cilium today)
```

## Why this is its own component

A cluster with no CNI has NotReady nodes, so nothing schedules. A Helm install
aimed at such a cluster does not fail fast — it times out and retries. So every
other platform component has to wait for this one rather than race it;
`xplane-platform` gates its FluxInit/FluxApps children on exactly that.

### The gate reports its own readiness

The RemoteCluster gate Object carries a `DeriveFromCelQuery` readiness that
asserts the observed `status.atProvider.clusterType` — the same field the render
gate reads. Until 0.2.0 it used provider-kubernetes' default
(`SuccessfulCreate`), so while the gate was closed the only composed resource
was ready by definition, no Release existed yet, and `function-auto-ready` put
`Ready=True` on the XR with no CNI installed — next to a correct
`status.ready: false`. Consumers reading the condition (`xplane-platform` does)
opened onto NotReady nodes. Either signal is safe now; see
[crossplane-configurations#439](https://github.com/stuttgart-things/crossplane-configurations/issues/439).

## Gateway API comes first

Cilium enables its Gateway controller **only if the CRDs exist when it starts**;
installed afterwards, `gatewayAPI.enabled` is a no-op until the operator and the
agents restart. With `spec.gatewayAPI.enabled` this module therefore installs the
CRDs as a Release of their own and **withholds the cilium Release until it is
Ready** — and sets `gatewayAPI.enabled` in the cilium values, so one switch
drives both.

That gate is sticky: once the cilium Release exists it keeps being emitted,
because not emitting a composed resource is how Crossplane deletes it.

The version is **paired with the cilium minor**, from the cilium docs:

| cilium | Gateway API | chart |
|---|---|---|
| 1.19.x | 1.4.1 | `oci://ghcr.io/stuttgart-things/charts/gateway-api-crds:1.4.1` |
| 1.20.x | 1.6.1 | `…:1.6.1` |

An unknown minor is not guessed — `spec.gatewayAPI.version` then has to say it,
and the render fails with that message if it does not. Upstream publishes no
Gateway API chart at all, which is why this points at the one in
`stuttgart-things/stuttgart-things` (`crossplane/platform/baseline/gateway-api-crds`)
that vendors the release manifest.

On rke2 the CRDs also arrive via `rke2-traefik-crd`, but after the CNI and at
rke2's pinned version — disable that chart (`ingress-controller: none` plus the
CRD chart in `disable`) and let this one own them.

## Spec

| field | default | notes |
|---|---|---|
| `clusterName` | — | derives `{clusterName}-helm` and the API server address |
| `helmProviderConfigRef` | `{clusterName}-helm` | explicit wins |
| `observeProviderConfigRef` | `in-cluster` | management cluster, for the gate |
| `provider` | `cilium` | only supported value today |
| `namespace` | `kube-system` | |
| `chart.version` / `chart.repository` | `1.19.6` / `https://helm.cilium.io/` | |
| `cilium.kubeProxyReplacement` | `true` | |
| `cilium.k8sServiceHost` | `{clusterName}-control-plane` | |
| `cilium.k8sServicePort` | `6443` | |
| `cilium.ipamMode` | `kubernetes` | |
| `cilium.operatorReplicas` | `1` | |
| `gatewayAPI.enabled` | `false` | install the Gateway API CRDs first, and turn on cilium's Gateway controller |
| `gatewayAPI.version` | paired with the cilium minor | Gateway API version = chart version |
| `gatewayAPI.chart.repository` / `.name` | `oci://ghcr.io/stuttgart-things/charts` / `gateway-api-crds` | explicit wins |
| `values` | `{}` | raw Helm values, merged last — wins over everything above |

### The API server address is not a detail

kind runs **without kube-proxy**. Nothing programs the `10.96.0.1` service VIP
until cilium is up, and cilium cannot come up if it needs that VIP to reach the
API server. `k8sServiceHost` breaks the circular dependency by naming the
control-plane container directly — `{clusterName}-control-plane` is exactly what
kind creates, which is why `clusterName` alone is enough.

`validate()` rejects `kubeProxyReplacement` with no resolvable address rather
than letting the cluster deadlock silently. With `kubeProxyReplacement: false`
the host/port are omitted entirely — a real kube-proxy makes normal discovery
work, and pinning a host would then be wrong, not merely redundant.

## Layout

- `logic.k` — all decisions, no `option("params")`, unit-tested
- `logic_test.k` — `kcl test .`
- `main.k` — marshals params in and `items` out

`kcl test .` compiles `main.k` too, so `validate()` is vacuously true on an
empty spec (no XR to check).

## Local render

```bash
kcl test .
kcl run -Y test-settings.yaml
```
