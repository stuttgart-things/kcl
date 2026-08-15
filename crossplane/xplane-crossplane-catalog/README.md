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

`function-kcl` additionally lives on **xpkg.upbound.io** while our `dependsOn`
entries use `xpkg.crossplane.io`. Two sources, two Lock nodes, healthy —
verified on kind1. Aligning the mirrors gives two nodes with an *identical*
source and freezes the resolver for every package on the cluster. The split is
load-bearing.

## Absences that are deliberate

| not listed | why |
|---|---|
| `provider-kubernetes` | every Configuration pulls it |
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
- `function-kcl` stays on the other mirror
- `function-auto-ready` stays below v0.7.0 — v0.7.0 makes Configurations report
  Unhealthy and times out the install wait
- every package pins an explicit tag; no floating tags
- `provider-kubernetes` is never installed explicitly
- `ProviderConfig`s are `in-cluster` only, carrying no credentials

## Profiles

| name | for |
|---|---|
| `machinery` | the full management cluster this fleet runs today — VM building, image building, backup, scheduling |

A seed profile will follow: a seed exists to produce exactly one cluster and
needs far less than this.
