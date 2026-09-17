# xplane-cluster

Composition logic for the `ClusterStack` XR in [stuttgart-things/crossplane-configurations](https://github.com/stuttgart-things/crossplane-configurations) (`bootstrap/cluster`, issue #169): one XR that builds a cluster from a bare VM up through its platform.

Depends on [`xplane-cluster-catalog`](../xplane-cluster-catalog/) for sizes and distributions.

## What it emits

```
ClusterStack                                                provisioner: ansible
├─ NativeProxmoxVM | NativeVsphereVM   {name}-vm            VM + base-OS ansible
├─ AnsibleRun                          {name}-distribution  k3s / kind install
├─ AnsibleRun                          {name}-kubeconfig    kubeconfig -> Vault
├─ ClusterAccess                       {name}-access        -> the ClusterProviderConfigs
├─ Platform                            {name}-platform      flux, apps, cilium, …
└─ Usage ×3                                                 teardown ordering
```

```
ClusterStack                                                provisioner: rancher
├─ Workspace                           {name}-kubeconfig-vault  owns kubeconfigs/<cluster>
├─ RancherCluster                      {name}-rancher       Rancher creates the cluster
├─ NativeProxmoxVM | NativeVsphereVM   {name}-vm            waits for the node command
├─ AnsibleRun                          {name}-join          join + kubeconfig -> Vault
├─ ClusterAccess                       {name}-access        -> the ClusterProviderConfigs
├─ Platform                            {name}-platform      cni (from the catalog), …
├─ VaultSecretSet ×n                   {name}-secrets-<app> per-cluster app secrets (0.17.0)
└─ Usage ×4                                                 + the VM outlives the RancherCluster
```

## Two provisioners (0.13.0)

The catalog entry decides which shape a stack has — `provisioner: ansible` (k3s, kind, rke2) or `provisioner: rancher` (`rancher-rke2`).

On the **rancher** path the cluster exists before any node does:

1. **`RancherCluster` first.** It creates the cluster in Rancher and publishes the node-registration command as a Secret. `nodeRegistration.publish` is forced on and `secretNamespace` defaults to the ansible pipeline namespace — `ansible-run` reads `extraEnvSecretName` from the **PipelineRun's** namespace, so a command published only next to the XR is one the join cannot read.
2. **The VM waits for that Secret.** A node that boots before Rancher minted a token has nothing to join, and the play would fail on an empty env var rather than retry. So `{name}-vm` is gated on `status.nodeCommandSecret`, read straight off the child.
3. **One join stage instead of two.** `{name}-join` runs `sthings.rke.rancher_register`, which registers the node **and** uploads its admin kubeconfig to Vault — both need this node at this moment. The command travels as an env Secret, never through `varsFile`: it carries a token, and varsFile lands in a ConfigMap. Re-runs work the same as elsewhere: `spec.runIDs.join`.
4. **Everything after is unchanged** — `ClusterAccess` reads the kubeconfig from Vault, `Platform` follows. The CNI is the difference: `cniOwnership: platform` on this entry, so the Platform installs cilium through the node kubeconfig, and the catalog's `cniDefaults` (API address, Gateway API, L2, externalIPs, hubble) are merged **under** whatever the caller put in `spec.platform.cni`.

**Why the CNI cannot come from Rancher:** every path Rancher offers runs through its proxy, which needs `cattle-cluster-agent` — an ordinary Deployment on the pod network. With no CNI it stays `Pending` and the Rancher kubeconfig answers 403. Measured on `rancher-join-test4`; see [crossplane-configurations#422](https://github.com/stuttgart-things/crossplane-configurations/issues/422).

**One extra Usage:** the VM must outlive the `RancherCluster`, which applies Objects *through* the cluster its own node runs (bootstrap namespace, Argo CD service account, vault reviewer). If the machine goes first those finalizers hang against a dead API server — the shape that took manual patching in #430.

`spec.rancher` is a verbatim passthrough of the `RancherCluster` spec, the same contract `spec.platform` has: `environmentConfig`, `argocd`, `vaultAuth`, `clusterSpec`, and `machineGlobalConfig` merged **over** the catalog's.

## Who owns `kubeconfigs/<cluster>` (0.14.0)

The upload writes that Vault entry; nothing removed it. A torn-down cluster left its kubeconfig behind — `rancher-join-test3` and `-test4` both did.

`spec.kubeconfig.lifecycle` composes a **Workspace** (provider-opentofu, the same machinery `VaultK8sAuth` uses) that claims the entry with `custom_metadata` and, on destroy, `DELETE`s `<mount>/metadata/<cluster>` — which removes every version. It never touches the secret data: the join play writes that, and `disable_read` keeps opentofu from diffing a value it does not own.

- **Default follows the provisioner:** on for `rancher`, off for the ansible path — not because that path does not leak the same entry (it does), but because turning it on changes the teardown of clusters that already exist. `enabled` wins either way.
- **`vaultAddr` is required when enabled.** The Workspace has to know which Vault it owns the entry in; the render fails saying so, and naming `enabled: false` as the alternative.
- **The credential** is the writer approle in `terraform.tfvars` form (`vault-kubeconfig-writer` by default). Its policy needs `create`/`update` on `kubeconfigs/metadata/*` — added and verified on the infra Vault on 2026-09-16; before that the same call was a 403.
- **Values travel as Workspace vars**, so the HCL stays a constant and a cluster name never lands inside a quoted HCL literal.
- **One more Usage:** `ClusterAccess` reads the entry, so the Workspace outlives it.

## Argo CD labels: profiles, derived facts, overrides (0.15.0)

`rancher-join-test5` carried ~35 hand-written labels and annotations and needed
five edits after it was ordered. That list mixed two different things, and the
stack now treats them differently:

**Choices** — which app platforms run. `spec.profiles` names catalog profiles
(`network`, `security`, `storage-openebs`, `observability`, `base`), so a choice
is a word, not a label set.

**Facts** — values this stack already knows because it composes them:

| derived | from |
|---|---|
| `auto-project: true` — without it no AppProject exists and every AppSet refuses its Applications (0.15.1, found on rancher-join-test6) | `rancher.argocd.register` |
| `clusterbook…/vault-server`, `…/wildcard-issuer-name`, `network-platform/cert-manager-vault-pki: false` | `platform.vaultIssuer` (enabled, and `platformEnabled`) |
| `external-secrets…/kv-mounts`, `security-platform/external-secrets-stores: true` | `spec.secretStores` |
| `observability-platform…/secrets-config: true`, `…/secret-store: vault-observability`, `…/alert-webhook-secret-key: _omni-pitcher` | `platform.clusterSecrets.enabled` **and** `observability` in `secretStores` |

The opt-in gates are only ever derived: each asserts that a Vault role can read
a mount, and only the stack composing that role can say so. Environment values
(`alert-webhook-url`) stay on the XR.

**Precedence:** profile < derived < `spec.rancher.argocd.{labels,annotations}`.
A hand-written value always wins.

Loud failures: an unknown profile; `secretStores` without `vaultIssuer`; or
without an `additionalAuths` entry named `eso` (the stores AppSet logs in through
`<cluster>-eso`). A stack with no `rancher.argocd`, no profiles and no stores gets
no `argocd` block, so existing RancherClusters see no diff.

## Vault token policies: derived, never passed through, in rancher mode (0.16.0)

A Kubernetes-auth role in Vault has no `allowed_policies`: whoever may write `auth/<mount>/role/*` may attach **any** existing policy, including ones they do not hold. Passing `tokenPolicies` from the order let whoever orders a ClusterStack bind, say, a `kubeconfigs` reader to a ServiceAccount on a cluster they control — cluster-admin on every cluster (crossplane-configurations#454).

In **rancher mode** the order names *stores*, never policies:

| auth | policies come from |
|---|---|
| cert-manager (`vaultIssuer.tokenPolicies`) | `vault.certManagerPolicies` in the EnvironmentConfig |
| `eso` — derived as a whole: SA `external-secrets/eso`, `createServiceAccounts`, policies | `vault.secretStores[<store>]` for every entry in `spec.secretStores` |

The mapping is an **environment** value — policy names differ per Vault — so it lives in the EnvironmentConfig labelled `cluster.stuttgart-things.com/environment: <spec.environmentConfig>`, cluster-scoped and admin-owned:

```yaml
data:
  vault:
    certManagerPolicies: [pki-issue]
    secretStores:
      homerun2-pr: [read-homerun2-pr]
      schmetterpause: [read-schmetterpause]
      observability: [read-observability-clusters]
```

The render **fails** on a hand-written `tokenPolicies` (on `vaultIssuer` or any `additionalAuths` entry), a hand-written `eso` entry, a store the environment does not map, and a missing `certManagerPolicies` while the issuer is enabled. The store map doubles as an allow-list: `secretStores: [kubeconfigs]` is rejected.

The **ansible path is unchanged** — seed-labda-1 passes `tokenPolicies` today; closing it there is a migration of its own.

## App secrets from AppSecretProfiles (0.17.0)

crossplane-configurations#464, step 5. A catalog profile names the `AppSecretProfile`s its workloads read (`appSecrets`, catalog 0.7.0); `profiles: [homerun2, tabletennis]` therefore selects the ApplicationSets **and** the secrets. Rancher mode only.

The stack fetches exactly those profiles (function-kcl `ExtraResources`, by name) and derives:

| derived | from |
|---|---|
| one `VaultSecretSet` `{name}-secrets-<app>` per app that owns entries: `<mount>/<cluster><suffix>`, `generate` / `literal` keys, `deleteAllVersions`, `mount.create: false` | the profile's `entries`; `vault.mounts`, `vault.writer.providerConfigName` |
| `spec.secretStores` + every real mount a consumer reads → eso policies and `kv-mounts` as in 0.16.0 | own mount, `vault.shared.<name>.mount`, the `from` source's mount |
| `<platform>.stuttgart-things.com/secrets-config: "true"` and `…/secret-store: vault-<mount>` | only where **one** store serves everything the platform reads |

`shared` and `from` keys are **never written**: consumers read the `_` entry or the owning app's entry directly. An order adopts an existing value per key instead of generating it:

```yaml
spec:
  profiles: [homerun2, tabletennis]
  secretOverrides:
    - {app: schmetterpause, key: password, vaultRef: {mount: schmetterpause, entry: schmetterpause, key: password}}
    - {app: homerun2, key: authToken, secretKeyRef: {name: homerun2-token, key: token}}   # XR namespace only
```

A list with `app`/`suffix`/`key` rather than an `app/key` string: app names contain dashes, so a string would be ambiguous (the same reason `reads[].from` is structured).

Environment half, next to the 0.16.0 keys:

```yaml
data:
  vault:
    secretStores: {homerun2: [read-homerun2-clusters], schmetterpause: [read-schmetterpause-clusters], observability: [read-observability-clusters]}
    mounts: {homerun2: homerun2, schmetterpause: schmetterpause}          # logical -> real
    shared:
      git-pat: {mount: homerun2, entry: _git-pat}
      object-store-backup: {mount: schmetterpause, entry: _backup}
    reservedEntries:                                                     # live hand-seeded entries
      schmetterpause: [schmetterpause, schmetterpause-backup, schmetterpause-scoreboard, zaehlwerk]
    writer: {providerConfigName: vault-cluster-secrets}
```

**The render fails** on: a listed `AppSecretProfile` that does not exist; a logical mount or shared name the environment does not map; a `from` naming an app no profile of the order brings; a key its source does not declare; an override for an unknown or non-overridable key, with zero or two sources, or twice; written entries without a writer; a cluster name ending in an entry suffix (`a-scoreboard` would own cluster `a`'s scoreboard entry); a written entry in `vault.reservedEntries`. Failing is also what protects the secrets: a failed function changes nothing, while a `VaultSecretSet` that is merely not emitted is **deleted with every version**.

Before Crossplane has answered the requirement (the first call of each reconcile) nothing is derived — that output is discarded. A profile that is not found is answered as empty, and fails loudly.

The `VaultSecretSet`s follow the **stack**, not the Platform: `platformEnabled: false` removes the stores and gates, never the generated values. `status.stages.appSecrets` lists the profiles, the sets and whether all are Ready.

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

Both sides of every `Usage` resolve their `apiVersion` through one kind→group map, `logic.groupOf`. A kind that is missing from it is a **KCL error at render time**, not a plausible default — which matters because a wrong group here is invisible: the `Usage` is admitted, goes `Ready`, and points at a group/kind pair that does not exist, so it guards nothing and the teardown runs through unordered with no error anywhere. `logic.vmKindOf` (provider→VM kind) is asserted against that map, so a fourth provider cannot be added without giving its kind a group.

## Provider differences: exactly one

`vm.memory` (Proxmox) vs `vm.ram` (vSphere), plus the fact that only Proxmox has a `cloudInit` block. Staging, gating and everything downstream are identical — that is option **A** of crossplane-configurations#168. A unit test asserts there is no second difference; if one appears, the "provider is a one-word switch" claim is no longer true and the README should stop saying it.

## Re-runs are per stage

### A finished stage is sealed (0.8.0)

Re-emitting a child verbatim is a flap guard — it applies while the VM's IP is
momentarily missing — but a **finished** `PipelineRun` needs the same treatment
for an unrelated reason: it is immutable. provider-kubernetes rejects any spec
change on one with `Once the PipelineRun is complete, no updates are allowed:
spec`, and keeps rejecting it every reconcile.

Until 0.8.0 the rebuild was keyed on the VM's IP and not on the stage, so ANY
edit to `spec.ansible` rewrote EVERY stage's spec — including stages that
finished hours ago. A change aimed at an open stage therefore parked a closed
one in a permanent `ReconcileError`, and the rebuild could not have delivered
the change anyway, because the write is refused.

The seal lifts the moment the derived name stops matching what is observed, so
the documented repair still works: bumping `spec.runIDs.<stage>` changes both
`pipelineRunName` and `crossplaneObjectName`, and the fix arrives as a NEW
Object instead of an update to a sealed one.

`spec.runIDs` is a map, not a single value:

```yaml
runIDs:
  kubeconfig: "2"    # re-runs the upload only
```

A single global `runID` was the first design and it is a footgun by construction: bumping it renames **every** stage, so repairing the kubeconfig upload also re-ran the k3s install against a live cluster. That happened on the first live build, and it is exactly the hazard the fleet's hand-written XRs warn about in their headers. A re-run has to name its stage.

The base-OS stage is deliberately absent from the map: it runs from the VM XR's own `spec.ansible`, whose XRD has no re-run knob, so it is not expressible from here.

## Per-stage ansible overrides

`ansible` is the shared block; `ansible.stages.<stage>` is **merged over** it, so the common case stays a single list:

```yaml
ansible:
  extraCollections: [...]                 # every stage
  stages:
    baseos:       {extraCollections: [...]}   # this stage only
    distribution: {extraCollections: [...]}
```

Why it exists: the shared list reaches every run, so pinning one collection for the base-OS stage silently replaced the set the k3s stage needed. On the first live build that meant restating `sthings-rke` — required only by the distribution stage — in order to bump `sthings-baseos`, required only by the base-OS stage.

### `setHostname`

The base-OS stage sets `vm_hostname` by default; on Proxmox that is what actually names the guest, since bpg cloud-init cannot without a snippets datastore.

It needs **`sthings-baseos >= 26.5.695`**. On an older collection set the var is **silently ignored** — the guest keeps the template's hostname and nothing reports an error. `ansible.setHostname: false` turns it off, so a fleet still on an older pin can make that explicit rather than wonder why the hostname is unset.

## The API endpoint is derived, not copied

Every `Platform` in the fleet states `vaultIssuer.kubernetesHost` by hand today — a copied node IP such as `https://10.31.102.108:6443`. It goes stale the moment the machine is rebuilt, and nothing notices until an issuer stops working.

`ClusterAccess` **discovers** the endpoint from the running cluster, so when `vaultIssuer` is enabled and `kubernetesHost` is not set, it is injected from `status.share.apiEndpoint`. An explicit value always wins — it may deliberately differ, e.g. a VIP or a load balancer in front of the API.

**This does not make the endpoint highly available.** It is still one node's address. It removes the hand-copied-value failure, not the single point of failure — see [crossplane-configurations#171](https://github.com/stuttgart-things/crossplane-configurations/issues/171), which also carries the finding that the fleet's ansible layer has no `tls-san` or kube-vip support today, so a real VIP needs work there first.

## What the user cannot set

`Platform.cni.enabled` comes from the catalog's `cniOwnership`, never from `spec.platform.cni.enabled`. A k3s role installs cilium itself; a kind cluster is built without one. Setting it by hand is how a cluster ends up with two CNIs. The user's other `cni` keys (chart version, values) pass through untouched — only `enabled` is overridden, and a test covers both halves.

`Platform.clusterName` is likewise supplied, not passed through.

## The cluster name goes into every var that names the cluster

`cluster_name` is passed to every stage, but it is not the handle every play reads. `sthings.container.kind` ignores it and names the cluster from **`kind_cluster_name`**, which its play defaults to `dev` — so a `ClusterStack` for `kindstack-test` built a kind cluster called `dev`, and the `Cni` child's `k8sServiceHost` (`<clusterName>-control-plane`) named a container that never existed. With `kubeProxyReplacement: true` that deadlocks: nothing programs the `10.96.0.1` VIP until cilium is up, so there is no fallback route to the API and every node stays `NotReady` ([crossplane-configurations#232](https://github.com/stuttgart-things/crossplane-configurations/issues/232)).

Which extra keys a distribution needs is a **catalog fact** (`Distribution.clusterNameVars`), not a branch on the distribution name here: this module states *"the name goes everywhere it is read"*, the catalog states where that is.

They are applied to **both** ansible stages, deliberately. `upload_kubeconfig_vault` derives `kubeconfig_path` from `kind_cluster_name` too, and before this fix both plays independently defaulted to `dev` and therefore agreed *by accident* — the upload worked only because the cluster was also wrongly named. Setting the name in the distribution stage alone would have broken it.

**Existing stacks are not retro-fixed.** The AnsibleRun children are re-emitted verbatim while the VM's IP is momentarily missing, and a completed Tekton `PipelineRun` is immutable — a cluster already built as `dev` stays `dev` until its stage is re-run with a bumped `runIDs.distribution` (`rebuild_kind_cluster` is `false`, so that re-run does not by itself rename a live cluster either). The fix applies to clusters built from here on.

## Layout

| file | role |
|---|---|
| `logic.k` | pure resource construction — explicit args in, dict out, unit-tested |
| `main.k` | wiring: reads `option("params")`, decides which gates are open, patches status |
| `logic_test.k` | 108 tests, no Crossplane and no cluster required |

`main.k` is deliberately thin and untested-by-unit: it is exercised by the Configuration's `crossplane render` with synthetic `--observed-resources`, which is the only way to test gate transitions honestly.

## Test

```bash
kcl test .
```

## Gotchas found while writing this (KCL, not Crossplane)

- **`kcl fmt` deleted code.** `[_acc := _acc | x for p in ps]` inside a lambda
  returned an empty dict without error, and `kcl fmt` then rewrote the line to
  `[_acc for p in ps]` — the expression was gone from the source. Diff after
  formatting.
- **A dict comprehension with a repeated key is an `EvaluationError`**, not an
  overwrite. "Later wins" needs `mergeLastWins`.
- **Unused lambdas are never evaluated.** A function calling a catalog function
  that did not exist passed `kcl test` until a test called it.

- **`kcl fmt` from a newer CLI can emit source the runtime cannot parse.** kcl 0.12.8 rewrites a long `lambda a: str, b: str -> T {` parameter list into a multi-line `lambda { a: str, … } -> T {` block. `function-kcl` v0.12.0 — the thing that actually runs this module — rejects that outright (`expected one of ["="] got ,`), so 0.3.1 was published unrenderable and superseded by 0.3.2. CI now pins `KCL_VERSION`; keep the two in step.
- **Commas are load-bearing in multi-line list literals.** `[a]` followed by a line starting with `[` parses as a *subscript*, silently dropping entries instead of failing. Cost an hour; the assembled `items` list carries a comment.
- **No `enumerate()`**, and no multi-line ternary chains — both are single-line or comprehension-only.
- **A dict literal is typed by its keys**, so `base | {newKey = …}` fails type checking. Tests write specs out in full instead of merging.
- **A bare top-level name is part of the output document.** `oxr`/`ocds` must be `_`-prefixed or `kcl run` echoes the whole observed state.
