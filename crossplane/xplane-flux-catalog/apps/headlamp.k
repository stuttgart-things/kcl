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
    defaultVersion = "v1.24.0"
    components = [
        s.Component {
            name = "app"
            path = "./"
            wrapsHelmRelease = True
            timeout = "15m"
            requiredSubstitutions = ["DOMAIN", "HOSTNAME", "GATEWAY_NAME"]
            # DOMAIN is the cluster's own domain — the same value the Gateway
            # listener's wildcard and the certificate CN are built from. Typing
            # it on the XR is how those three drift apart; the platform already
            # discovered it, and so is GATEWAY_NAME — the platform sets that
            # name on the Gateway it creates. HOSTNAME stays manual: which name
            # this app answers on, and which Gateway it attaches to, are
            # decisions no status can answer.
            substitutionSources = {
                DOMAIN = "ipReservation.domain"
                # No longer a required substitution: the platform publishes the
                # Gateway's name it also creates it with, so nobody states it.
                GATEWAY_NAME = "gateway.name"
            }
        }
    ]
}
