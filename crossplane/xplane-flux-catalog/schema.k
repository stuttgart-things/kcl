"""
Structural definitions for the stuttgart-things Flux app catalog.

Deliberately holds STRUCTURAL facts only — where an app's manifests live, how its
components are ordered, how long they take to install. Substitution VALUES
(DAPR_NAMESPACE, DAPR_VERSION, ...) are environment-specific and stay in the XR
or a per-cluster EnvironmentConfig; each app's own README in stuttgart-things/flux
is their source of truth, and duplicating them here would guarantee drift.
"""

schema Component:
    """
    One Flux Kustomization within an app.

    An app is NOT necessarily a single Kustomization: dapr ships a control-plane
    and a template-execution component, the second depending on the first.
    """
    name: str
    """Kustomization name suffix — the emitted name is '{app}-{name}'"""

    path: str
    """Path within the OCI artifact. The artifact root IS the app directory,
    so this is './components/control-plane', not './apps/dapr/components/...'"""

    dependsOn?: [str] = []
    """Other component names (within this app) that must be Ready first"""

    timeout?: str
    """Overrides the FluxApps default. Set 15m on components that wrap a
    HelmRelease — chart pull + rollout regularly exceeds the 10m default"""

    wrapsHelmRelease?: bool = False
    """Documentation flag: this component installs a HelmRelease. Explains why
    timeout is raised and signals that readiness depends on a chart rollout"""

schema App:
    """A deployable app, published as one OCI artifact by stuttgart-things/flux."""
    artifact: str
    """oci:// URL of the artifact — one artifact per app, so the source name
    and the app name are the same fact. This is what lets platform emit both
    the flux-init source and the flux-apps entry from a single toggle"""

    defaultVersion: str
    """OCI tag used when the XR does not pin one"""

    components: [Component]
    """At least one. Ordered for readability; real ordering comes from dependsOn"""

    check:
        artifact.startswith("oci://"), "artifact must be an oci:// URL"
        len(components) > 0, "an app needs at least one component"

