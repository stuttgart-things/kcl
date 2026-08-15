# xplane-management-plane

`function-kcl` module for the **management-plane** Crossplane Configuration.

Turns a cluster into a *management* cluster: installs Crossplane on it, then the
packages and provider configs that let it build other clusters.

```
1. helm.m.crossplane.io Release       the crossplane chart
2. kubernetes.m.crossplane.io Object  one per Provider / Function / Configuration
3. kubernetes.m.crossplane.io Object  one per in-cluster ProviderConfig
```

## What it installs is not in the XR

The package set comes from
[`xplane-crossplane-catalog`](../xplane-crossplane-catalog/), resolved through
`spec.profile` (default `machinery`). It is a fleet fact, not a per-cluster
choice, and it belongs where it can be version-controlled and tested — the
catalog asserts the naming rule that keeps the
[#247](https://github.com/stuttgart-things/crossplane-configurations/issues/247)
Lock collision impossible.

A cluster can still break out, per package:

```yaml
spec:
  clusterName: mgmt-1
  packageOverrides:
    stuttgart-things-crossplane-configurations-platform:
      ghcr.io/stuttgart-things/crossplane-configurations/platform:v0.3.9
```

The override replaces the **whole reference**, not just the tag — deliberately.
A tag-only override would silently keep the catalog's registry, and which mirror
a package comes from is load-bearing here: `function-kcl` sits on
`xpkg.upbound.io` precisely because our `dependsOn` entries use
`xpkg.crossplane.io`.

An override naming a package the profile does not carry is **rejected**. Doing
nothing would leave the caller believing a version was pinned when it was not —
and the key is the CR name, so `platform` is not the same thing as
`stuttgart-things-crossplane-configurations-platform`.

## Why not part of `platform`

`platform` answers *what does this cluster offer*. Being a management cluster is
a **role**, and the two have different lifetimes: a workload cluster's apps
change weekly, its control plane does not.

## The gates, and why they only open

The install order is forced by CRDs rather than preference — the
`pkg.crossplane.io` CRDs arrive *with* Crossplane, and each provider's
`ProviderConfig` CRD arrives with that provider. Emitting everything at once
still converges, because the Objects retry; what it costs is the ability to
diagnose a failed bootstrap, since the real errors are buried under minutes of
expected ones.

So packages wait for the Crossplane Release, and provider configs wait for the
packages.

**Every gate is one-way.** Not emitting a composed resource is how Crossplane
deletes it — a gate that closed again would tear the cluster down: a Crossplane
Deployment briefly NotReady would uninstall the whole fleet's packages. Once a
resource has been emitted it keeps being emitted, which the tests pin.

## Status

```yaml
status:
  ready: true
  profile: machinery
  crossplaneVersion: 2.3.3
  components:
    crossplane:      {ready: true, version: 2.3.3}
    packages:        {total: 20, ready: 20}
    providerConfigs: {total: 3, emitted: 3}
  transitive: [ansible-run, cni, flux-apps, flux-init, ip-reservation, ...]
```

`transitive` is there because "which packages are on this cluster" cannot be
answered from the spec: eleven of them arrive through some other package's
`dependsOn` without ever being named.

## Not yet covered

Cluster-scoped **RBAC** — the `rbac.yaml` manifests from `remote-cluster` and
`ip-reservation`, and the `cluster-admin` binding some providers need. The
machinery play applies them from raw URLs today. Left out of 0.1.0 rather than
guessed at: binding a provider's ServiceAccount by name is exactly the trap
[crossplane-configurations#251](https://github.com/stuttgart-things/crossplane-configurations/issues/251)
fixed (the name carries a generated hash), and the group-based alternative wants
deciding, not inventing.

Capability charts are also out, and stay out: their values are per-environment,
which is the line this module and the catalog both hold.
