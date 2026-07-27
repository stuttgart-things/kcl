# xplane-cluster

Composition logic for the `ClusterStack` XR in [stuttgart-things/crossplane-configurations](https://github.com/stuttgart-things/crossplane-configurations) (`bootstrap/cluster`, issue #169): one XR that builds a cluster from a bare VM up through its platform.

Depends on [`xplane-cluster-catalog`](../xplane-cluster-catalog/) for sizes and distributions.

## What it emits

```
ClusterStack
├─ NativeProxmoxVM | NativeVsphereVM   {name}-vm            VM + base-OS ansible
├─ AnsibleRun                          {name}-distribution  k3s / kind install
├─ AnsibleRun                          {name}-kubeconfig    kubeconfig -> Vault
├─ ClusterAccess                       {name}-access        -> the ClusterProviderConfigs
├─ Platform                            {name}-platform      flux, apps, cilium, …
└─ Usage ×3                                                 teardown ordering
```

## The two things that make this non-trivial

### Sticky, success-based gates

Every stage is gated on `(the previous stage SUCCEEDED) OR (this child already exists)`.

The second clause is not defensive programming — it is the difference between working and destructive. **Not emitting a composed resource is what makes Crossplane delete it**, and bpg / VMware Tools both read the VM address from the guest agent, so a momentarily empty value is normal rather than exceptional. Without stickiness a blip deletes an `AnsibleRun`, and its recreation re-runs the play against a live machine. That failure was real (crossplane-configurations#163).

The `AnsibleRun` children are additionally re-emitted **verbatim from `ocds`** rather than rebuilt: during the very blip being defended against the IP is empty, so a rebuild would rewrite the inventory to nothing — and since the wrapped Object excludes `Update`, that rewrite would silently never reach Tekton.

Gates check **`succeeded`, not `Ready`**. An `AnsibleRun` whose PipelineRun failed still reports Ready once its Object is applied; unblocking on that would run a kubeconfig upload against a cluster that was never installed.

### Teardown ordering

Three `Usage` resources, only the pairs whose absence strands a finalizer:

| `of` (dies last) | `by` (dies first) | why |
|---|---|---|
| VM | Platform | else every Platform Object hangs against a dead API server |
| ClusterAccess | Platform | else the ClusterProviderConfigs its Objects reference are gone before they can be finalized |
| VM | ClusterAccess | so the Vault read ends before the machine does |

`Usage` orders **deletion only, never creation** — build order stays the ready gates. The AnsibleRuns need no protection: they only create PipelineRuns on the management cluster, and those disappearing blocks nobody.

## Provider differences: exactly one

`vm.memory` (Proxmox) vs `vm.ram` (vSphere), plus the fact that only Proxmox has a `cloudInit` block. Staging, gating and everything downstream are identical — that is option **A** of crossplane-configurations#168. A unit test asserts there is no second difference; if one appears, the "provider is a one-word switch" claim is no longer true and the README should stop saying it.

## What the user cannot set

`Platform.cni.enabled` comes from the catalog's `cniOwnership`, never from `spec.platform.cni.enabled`. A k3s role installs cilium itself; a kind cluster is built without one. Setting it by hand is how a cluster ends up with two CNIs. The user's other `cni` keys (chart version, values) pass through untouched — only `enabled` is overridden, and a test covers both halves.

`Platform.clusterName` is likewise supplied, not passed through.

## Layout

| file | role |
|---|---|
| `logic.k` | pure resource construction — explicit args in, dict out, unit-tested |
| `main.k` | wiring: reads `option("params")`, decides which gates are open, patches status |
| `logic_test.k` | 15 tests, no Crossplane and no cluster required |

`main.k` is deliberately thin and untested-by-unit: it is exercised by the Configuration's `crossplane render` with synthetic `--observed-resources`, which is the only way to test gate transitions honestly.

## Test

```bash
kcl test .
```

## Gotchas found while writing this (KCL, not Crossplane)

- **Commas are load-bearing in multi-line list literals.** `[a]` followed by a line starting with `[` parses as a *subscript*, silently dropping entries instead of failing. Cost an hour; the assembled `items` list carries a comment.
- **No `enumerate()`**, and no multi-line ternary chains — both are single-line or comprehension-only.
- **A dict literal is typed by its keys**, so `base | {newKey = …}` fails type checking. Tests write specs out in full instead of merging.
- **A bare top-level name is part of the output document.** `oxr`/`ocds` must be `_`-prefixed or `kcl run` echoes the whole observed state.
