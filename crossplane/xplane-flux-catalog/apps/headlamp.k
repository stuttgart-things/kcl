import ..schema as s

# headlamp — https://github.com/stuttgart-things/flux/tree/main/apps/headlamp
#
# Single component: the artifact root kustomization pulls requirements.yaml
# (Namespace + HelmRepository), release.yaml (HelmRelease) and rbac.yaml, so the
# path is "./" rather than a components/ subdirectory.
#
# DOMAIN, HOSTNAME and GATEWAY_NAME have NO defaults in the manifests and are
# used to build the HTTPRoute — Flux would substitute them with empty strings and
# deploy something silently broken, so they are declared required.
# The Gateway they reference must already exist on the target cluster.
headlamp: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/apps/headlamp"
    defaultVersion = "v1.18.1"
    components = [
        s.Component {
            name = "app"
            path = "./"
            wrapsHelmRelease = True
            timeout = "15m"
            requiredSubstitutions = ["DOMAIN", "HOSTNAME", "GATEWAY_NAME"]
        }
    ]
}
