import ..schema as s

# trust-manager — https://github.com/stuttgart-things/flux/tree/main/infra/trust-manager
#
# The first CROSS-ARTIFACT dependency in the catalog: trust-manager's CRDs and
# webhook require cert-manager, so it cannot reconcile until cert-manager's own
# Kustomization is Ready. The upstream README states this as
# `dependsOnNames=cert-manager-install`, which is exactly the name this catalog
# emits for cert-manager's install component.
#
# All of its own variables have manifest defaults, so nothing is required.
trustManager: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/infra/trust-manager"
    defaultVersion = "v1.18.1"
    components = [
        s.Component {
            name = "install"
            path = "./"
            wrapsHelmRelease = True
            timeout = "15m"
            dependsOn = ["cert-manager:install"]
        }
    ]
}
