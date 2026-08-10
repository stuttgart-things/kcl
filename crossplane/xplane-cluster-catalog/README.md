# xplane-cluster-catalog

Structural facts about the cluster shapes the stuttgart-things fleet builds: what a t-shirt `size` means, and how each Kubernetes distribution is installed.

Consumed by the `cluster` Configuration in [stuttgart-things/crossplane-configurations](https://github.com/stuttgart-things/crossplane-configurations) (issue #167 / #169), the same way [`xplane-flux-catalog`](../xplane-flux-catalog/) is consumed by `xplane-platform`.

## Why this exists

The knobs a cluster varies on were spread across three unrelated places, and the rules connecting them existed only as **prose comments**. The sharpest example, from `xrs/proxmoxvm/labul/kind1/remotecluster-u26-kind1.yaml`:

> This cluster already runs cilium (installed by `sthings.rke.k3s_cluster`, which must install it — the k3s config disables flannel and kube-proxy). A Platform XR for u26-kind1 must therefore leave `cni.enabled` off, or it would install a second CNI.

and its mirror image in `platform-kind-test1.yaml`, where `cni.enabled: true` is correct *because* the kind cluster is deliberately built without one. Two clusters, opposite settings, and the only thing preventing a mistake was that someone read the comment.

Here it is `cniOwnership`, and `platformCniEnabled(name)` derives the Platform setting from it. A unit test asserts the two are opposites.

## What it holds — and what it does not

**Structural facts only**: core counts, playbook names, var names, required inventory groups, CNI ownership. Environment-specific *values* — IPs, endpoints, Vault roles, credentials, template UUIDs — stay in the per-environment `EnvironmentConfig` or on the XR. Same line `xplane-flux-catalog` draws for apps.

## Sizes

| size | cpu | memory | disk | masters |
|---|---|---|---|---|
| `small` | 2 | 4096 | 40 | 1 |
| `medium` | 4 | 8192 | 64 | 1 |
| `large` | 8 | 16384 | 100 | 1 |
| `medium-ha` | 4 | 8192 | 64 | **3** |

Values are a rounding of what the fleet actually runs, not new invention: `small` is the vspherevm XRD default, `large` matches `kind-test1` (sized for a kind cluster plus crossplane, flux and the app catalog on top).

All values are **strings** — both VM XRDs take strings, and emitting ints fails schema validation on the composed resource. A unit test enforces it.

`medium-ha` is present so the shape is reviewable, but no current distribution accepts it: `assertSizeSupported()` rejects `masters > 1` unless the distribution declares `multiNode`. That is gated on crossplane-configurations#170 (static addressing + an aggregate ready gate) and #171 (the API endpoint is a single node IP today, so three masters would be HA in name only).

## Distributions

| | `k3s` | `kind` |
|---|---|---|
| playbook | `sthings.rke.k3s_cluster` | `sthings.container.kind` |
| version pin | `k3s_k8s_version 1.35.1`, `k3s_release_kind k3s1` | `kind_version 0.31.0`, `kubectl_version 1.35.0` |
| CNI ownership | `self` — the role installs cilium | `platform` — built deliberately without one |
| inventory groups | `initial_master_node`, `additional_master_nodes`, `workers` | `all` |
| cluster-name vars | — (`cluster_name` only) | `kind_cluster_name` |
| multi-node | no | no |

Every var in the tables is load-bearing, with the incident history in the comments. Two worth repeating:

- **k3s `install_cilium: "true"` is mandatory.** The role's `k3s_config` default writes `flannel-backend=none`, `disable-kube-proxy=true` and `disable-network-policy=true` — k3s comes up deliberately without a CNI *and* without kube-proxy. With it false the cluster has no working pod network at all.
- **k3s's three inventory groups are not cosmetic.** `sthings.rke.deploy_configure_rke` branches on `groups['initial_master_node']` and `groups['additional_master_nodes']`; a flat `all+[...]` inventory fails with an undefined-group error. Empty groups render as header-only INI sections, which ansible registers as existing-but-empty — exactly what the role's `in groups[...]` tests need.

### The cluster name is not one var

`cluster_name` is what the consumer passes to every stage, but it is **not** a universal handle. `sthings.container.kind` never reads it: the cluster is named from `kind_cluster_name`, which the play defaults to `dev`. A `ClusterStack` asking for `kindstack-test` therefore built a kind cluster called `dev`, and the Platform's `Cni` child — whose `k8sServiceHost` defaults to `<clusterName>-control-plane` — aimed cilium at a container that was never created. With `kubeProxyReplacement: true` that is a **deadlock**, not a slow failure: cilium cannot fall back to the `10.96.0.1` VIP either, because nothing programs that VIP until cilium is up. All nodes stay `NotReady`, the operator crashloops, the agents sit in `Init:0/6` ([crossplane-configurations#232](https://github.com/stuttgart-things/crossplane-configurations/issues/232)).

So `clusterNameVars` names the extra keys that must carry the cluster name, and the consumer applies them to **every** stage — not just the distribution one. That second half is load-bearing: `sthings.container.upload_kubeconfig_vault` derives `kubeconfig_path` from `kind_cluster_name` as well, so before this field both plays independently defaulted to `dev` and agreed *by accident*. Setting the name in the distribution stage alone would have broken an upload that used to work.

With the name set, `kind_cluster_name == clusterName` and the `Cni` XRD's default becomes correct by construction — the fix is one fact, not two derivations kept in sync.

### Versions are pinned per distribution, not globally

Each distribution pins its own versions, and a test asserts that none is left unpinned. Unpinned meant real drift: a live build produced k3s **v1.36.1** while the hand-written XR this catalog replaces pins **1.35.1**, so two clusters from the same profile could differ by build date.

There is deliberately **no shared `kubernetesVersion` field**, because the two distributions do not pin the same thing:

- `k3s` pins **Kubernetes** (`k3s_k8s_version` + `k3s_release_kind`);
- `kind` pins the **kind binary** (`kind_version`) — its Kubernetes version follows from the node image that binary defaults to.

One field mapped onto both would be accurate for one and a lie for the other. If a per-cluster override is ever wanted, it belongs per distribution and only once *changing* it is supported — today a version change re-runs the install play against a live cluster, which is [#172](https://github.com/stuttgart-things/crossplane-configurations/issues/172) territory.

**`rke2` is deliberately absent.** The fleet runs multinode rke2 through ansible (`exec/labul/sthings-infra-rke2`), but no Crossplane path has ever built one, so an entry here would be a guess wearing the same clothes as a verified fact. Add it after a reference run — a unit test currently asserts its absence, so adding it forces updating that test in the same commit.

## The kubeconfig-upload stage

`kubeconfigStage` is shared across distributions and deliberately **separate** from the distribution playbooks. A completed Tekton `PipelineRun` is immutable, so folding the upload into the distribution run would mean re-running the whole cluster build — including `cilium install` against a live cluster — to redo an upload. A unit test asserts no distribution absorbs it.

> **Decided:** this per-stage split is option **A** of crossplane-configurations#168 — normalize both providers onto per-stage runs — chosen 2026-07-27, staggered: the `cluster` Configuration emits per-stage runs for both providers from the start, while `machinery/vspherevm`'s own combined-run path stays as it is for direct users. So `Distribution` needs no `staging` key.

## API

```python
import xplane_cluster_catalog as cat

cat.getSize("medium")                       # -> Size, fails loudly on unknown
cat.getDistribution("k3s")                  # -> Distribution, ditto
cat.platformCniEnabled("k3s")               # -> False
cat.assertSizeSupported("k3s", "medium-ha") # -> fails: no verified multi-node path
cat.kubeconfigStage                         # -> Stage
cat.sizeNames, cat.distributionNames        # sorted names, for error messages
```

## Test

```bash
kcl test .     # 16 tests, no Crossplane and no cluster required
```

The tests are the point: these rules — CNI ownership, the mandatory cilium var, the inventory groups, the separate upload stage — are exactly what should fail in CI rather than on a live cluster.
