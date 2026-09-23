# xplane-crossplane-catalog

The package set that makes a cluster a **management** cluster: Crossplane itself,
its providers, functions and configurations.

Sibling of [`xplane-flux-catalog`](../xplane-flux-catalog/), one layer down. That
one describes what a cluster *offers*; this one describes what it *is*.

```kcl
import xplane_crossplane_catalog as cat

_p = cat.get("machinery")
_p.crossplaneVersion              # "2.3.3"
cat.byKind(_p, "Configuration")   # apply these last
cat.transitive(_p)                # what arrives without being named
```

## Scope

**Structural facts only**, the same discipline the flux catalog keeps. Package
identity and version live here because they are identical on every management
cluster in this fleet. Capability-chart values, credentials and per-datacentre
placement do not — they are environment-specific and belong in the XR or an
`EnvironmentConfig`. Duplicating them here would guarantee drift.

## The naming rule, and why it is the whole point

Providers and Configurations carry the name **Crossplane itself derives** from
the package path — registry dropped, segments joined with `-`, tag stripped:

```
xpkg.crossplane.io/crossplane-contrib/provider-helm:v1.3.0
  -> crossplane-contrib-provider-helm

ghcr.io/stuttgart-things/crossplane-configurations/platform:v0.3.11
  -> stuttgart-things-crossplane-configurations-platform
```

This is not cosmetic. The package resolver keys on the **source**, so an
existing node satisfies a `dependsOn` no matter what its CR is called — which is
why a fleet cluster looks healthy with short names most of the time. The window
opens during an **upgrade**: the CR's Lock entry briefly disappears, the resolver
sees an unsatisfied dependency and auto-installs it under the derived name, and
when the short-named CR returns there are two names for one source. That is
[crossplane-configurations#247](https://github.com/stuttgart-things/crossplane-configurations/issues/247):
on u26-kind3 it took **all 20 Configurations** to `Healthy=False`, and unpicking
it is whack-a-mole, because deleting one duplicate makes the resolver create the
next.

With the derived name, the CR the resolver would create and the CR that already
exists are the same object. There is no window.

### Functions are the exception

They keep **short** names (`function-kcl`, never
`crossplane-contrib-function-kcl`) because Compositions name them in
`functionRef` — renaming one breaks every Composition that uses it. Functions
therefore retain a narrow exposure to the upgrade window above. There is no way
around it that does not break `functionRef`, so it is documented rather than
fixed.

**Every short Function sits on `xpkg.upbound.io`, every twin on
`xpkg.crossplane.io`** — the registry our `dependsOn` entries name. Two
sources, two Lock nodes, healthy. One source under two names is one node twice,
and then *no* package on the cluster resolves. The versions may match: kind5
runs `function-kcl` v0.12.2 on both mirrors, same digest, both Healthy. What
must never match is the source.

Since 0.8.0 all five twins are listed too, so they are pinned rather than
floating.

### Why that only showed up on a Flux cluster

Until 0.8.0 `function-auto-ready`, `-go-templating` and `-environment-configs`
were on `xpkg.crossplane.io`, the same registry as their twins. Every kind
cluster was fine, because the `kind_machinery` play installs the functions
**before** the Configurations: the resolver finds the short CR by source and
creates no twin at all. Flux applies the whole list in one pass, the twin is
created from a `dependsOn` while the short CR is still reconciling, and the
second name lands on a source that already has one. On `machinery`
(2026-09-22) that took **all 51 packages** to `Healthy=False`, with the Lock
holding `xpkg.crossplane.io/crossplane-contrib/function-go-templating` twice.

Same catalog, different install order, and only one of the two orders shows
it — which is why the rule is now asserted rather than described.

### Listed although pulled — to pin them

`crossplane-contrib-provider-kubernetes`, `valkiriaaquaticamendi-provider-proxmox-bpg`,
`upbound-provider-vault` and `vshn-provider-minio` all arrive through some
Configuration's `dependsOn`. They are listed anyway, since 0.7.0, because under
the derived name the explicit CR *is* the dependsOn node — listing it adds no
node, it pins the version. Unpinned, a fresh cluster gets whatever the
constraint allows that day (u26-kindtest came up with provider-kubernetes 1.3.1
and proxmox-bpg 1.19.3 next to kind3's 1.2.1 / 1.18.0).

**The registry is part of the identity.** Each entry names exactly the path its
`dependsOn` names. Moving one to another mirror is a second Lock node and takes
every package to `Healthy=False`; `kcl test` pins the registries.

The same holds for the two function **twins**, `crossplane-contrib-function-kcl`
and `crossplane-contrib-function-patch-and-transform`: the only Functions allowed
a long name, and only as the exact derived name on `xpkg.crossplane.io`.

### Provider runtime: `env` and `resources`

A Provider may carry `env` and `resources`. Consumers render them as a
`DeploymentRuntimeConfig` named like the provider plus a `runtimeConfigRef` to
it — the shape stuttgart-things/helm emits from the same two fields.
`upbound-provider-opentofu` and `valkiriaaquaticamendi-provider-proxmox-bpg` get
`POLL=1h` / `SYNC=6h` and CPU limits: at the image defaults each re-runs
terraform per managed resource per poll, which held u26-kind3 at load 8 and cost
~3950 control-plane restarts in 39 days. `env` values are strings, and the schema
rejects either field on anything but a Provider.

## Absences that are deliberate

| not listed | why |
|---|---|
| `ansible-run` | pulled by both VM Configurations |
| `cni`, `flux-init`, `flux-apps`, `ip-reservation`, `vault-auth`, `vault-pki-secrets` | pulled by `platform` |

They are recorded in each package's `pulls`, which is documentation rather than
an exclusion list — with derived names an entry may legitimately be both
installed and pulled, because the two are one node. `cat.transitive(profile)`
returns the whole set: the honest answer to what is actually on the cluster.

## Invariants

`kcl test` asserts the rules rather than trusting the next reader to know them:

- every Provider and Configuration uses the derived name
- the derivation matches Crossplane's, for both the upstream and the ghcr path shape
- Function CR names stay short
- no two packages share a source — the rule the whole Lock rests on
- short Functions sit on `xpkg.upbound.io`, their twins on `xpkg.crossplane.io`,
  and every short Function has its twin pinned
- a long Function name is only the exact dependsOn twin on `xpkg.crossplane.io`,
  and never without its short sibling
- `function-auto-ready` stays below v0.7.0 — v0.7.0 makes Configurations report
  Unhealthy and times out the install wait
- every package pins an explicit tag; no floating tags
- `provider-kubernetes` is pinned under the derived name, never the short one
- pulled providers are pinned on exactly the registry their `dependsOn` names
- opentofu and proxmox-bpg carry the poll/sync tuning
- `ProviderConfig`s are `in-cluster` only, carrying no credentials

## Profiles

| name | for |
|---|---|
| `machinery` | the full management cluster this fleet runs today — VM building, image building, backup, scheduling |

A seed profile will follow: a seed exists to produce exactly one cluster and
needs far less than this.
