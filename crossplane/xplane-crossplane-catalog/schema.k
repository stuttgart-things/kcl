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

    runtimeConfig?: str
    """A DeploymentRuntimeConfig this provider's pod must run with.

    STRUCTURAL, and it has to live here rather than beside the object that
    creates that config. Crossplane creates the Provider CR from a package
    path, so whoever ships the DeploymentRuntimeConfig -- a Helm chart, a
    Kustomization -- cannot also own `spec.runtimeConfigRef` on the CR without
    becoming its second owner. The kind machinery play works around that with a
    kubectl patch after the fact; a Flux cluster has no such moment, so the
    reference belongs in the package definition.

    The config itself is NOT created here. The name is a contract: something
    else on the cluster must supply it, and a provider pointed at a missing one
    does not start. First case: provider-kubeconfig, whose
    `provider-kubeconfig-vault` chart mounts the lab CA bundle -- without it
    every Vault login fails with "x509: certificate signed by unknown
    authority", which reads like a credential problem and is not one.
    """

    env?: {str:str}
    """Environment for the provider's `package-runtime` container, rendered as a
    DeploymentRuntimeConfig named like the provider plus a runtimeConfigRef to
    it. Strings only: a container env value is one, and a bare number or bool
    would be rejected by the API server.

    env, never args: args in a DeploymentRuntimeConfig REPLACE the image's own
    arguments instead of adding to them, and every upjet flag has an
    environment variable.

    A fleet fact, not tuning: at the image defaults an upjet provider re-runs
    terraform per managed resource per poll, which held u26-kind3 at load 8 and
    cost ~3950 control-plane restarts in 39 days. The same values sit in
    stuttgart-things/helm cicd/crossplane-providers.yaml.gotmpl."""

    resources?: {str:{str:str}}
    """requests / limits for the same container. Quantities as strings."""

    check:
        ":" in package, "package must carry an explicit tag"
        not package.endswith(":latest"), "package must not use a floating tag"
        not env or kind == "Provider", "env is a provider runtime setting"
        not resources or kind == "Provider", "resources is a provider runtime setting"

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

