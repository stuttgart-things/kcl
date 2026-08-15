"""
Structural definitions for the stuttgart-things Crossplane package catalog.

The sibling of xplane-flux-catalog, for the layer below it: that one describes
what a cluster OFFERS, this one describes what makes a cluster a MANAGEMENT
cluster — Crossplane itself, its providers, functions and configurations.

Same discipline, deliberately: STRUCTURAL facts only. Package identity and
version live here because they are the same on every management cluster in this
fleet. Anything environment-specific — capability chart values, credentials,
per-datacentre placement — stays out, in the XR or an EnvironmentConfig, for the
reason the flux catalog states: duplicating it here would guarantee drift.
"""

schema Package:
    """One Crossplane package CR: a Provider, Function or Configuration."""
    kind: "Provider" | "Function" | "Configuration"

    name: str
    """The CR's metadata.name. NOT cosmetic.

    Providers and Configurations use the name Crossplane DERIVES from the
    package path (see main.derivedName) — `crossplane-contrib-provider-helm`,
    `stuttgart-things-crossplane-configurations-platform`. That is what makes an
    explicit CR and a dependsOn-derived one the same Lock node instead of two.

    Functions are the exception and must stay SHORT (`function-kcl`, never
    `crossplane-contrib-function-kcl`), because Compositions name them in
    `functionRef` — renaming one breaks every Composition that uses it. Functions
    therefore keep a narrow exposure to the upgrade window described in
    main.derivedName; there is no way around it that does not break functionRef.
    """

    package: str
    """Full OCI reference INCLUDING the tag. Floating tags are rejected: a
    management cluster that silently moves a provider forward is how a fleet
    breaks overnight."""

    apiVersion?: str
    """Package API version, when it is not the default `pkg.crossplane.io/v1`.
    Functions are split across v1 and v1beta1 upstream and it is not guessable
    from the name — function-kcl and function-environment-configs are v1,
    function-auto-ready and function-go-templating are v1beta1."""

    pulls?: [str] = []
    """Packages this one brings in transitively through its own dependsOn.

    Documentation, not an exclusion list — with derived names an entry may be
    both installed explicitly and pulled by another package, because the two
    are the same Lock node. What it buys is an honest answer to "what is
    actually on this cluster", and a check that a package named here really is
    reachable, so the graph cannot rot unnoticed.

    Declared rather than inferred because the catalog cannot read OCI metadata.
    """

    providerCrd?: str
    """A CRD this package registers, worth waiting for before anything that
    references it. Omit when the package registers nothing new."""

    clusterRole?: str
    """ClusterRole to bind the provider's ServiceAccount to. Only providers that
    manage arbitrary cluster content need one."""

    check:
        ":" in package, "package must carry an explicit tag"
        not package.endswith(":latest"), "package must not use a floating tag"

schema ProviderConfig:
    """A cluster-scoped ProviderConfig pointing a provider at its OWN cluster.

    Every management cluster needs these and they carry no environment-specific
    values — which is why they belong here and the per-datacentre ones (vSphere,
    Proxmox, Vault) do not."""
    name: str
    apiVersion: str
    kind: str
    spec: {str:any}

schema Profile:
    """One kind of management cluster."""
    crossplaneVersion: str
    """Chart version of crossplane-stable/crossplane."""

    namespace?: str = "crossplane-system"
    packages: [Package]
    providerConfigs?: [ProviderConfig] = []

    check:
        len(packages) > 0, "a profile installs at least one package"

