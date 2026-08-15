import ..schema as s

# machinery — https://github.com/stuttgart-things/flux/tree/main/apps/machinery
#
# NOT the machinery bootstrap play, despite the name: this is the Go service
# from stuttgart-things/machinery that watches Crossplane-managed custom
# resources and serves them over gRPC (:50051, incl. WatchResources) and an
# HTMX dashboard (:8080). Same word, different thing — worth stating here
# because the collision is easy to trip over.
#
# It reads the CRs of the cluster it runs on, so it belongs on a management
# cluster, where those are the ClusterStack / Platform / XIPReservation XRs
# whose `status` fields are the whole point of this fleet's design. Its
# configurable status-field extraction is what makes `status.stage` — "the one
# field to look at when a build is stuck" — visible without kubectl.
#
# TWO GAPS in the artifact, both verified 2026-08-14 — neither blocks the
# catalog entry, but both bite whoever enables it first:
#
#  1. MACHINERY_VERSION defaults to `1.13.4`; the published tags are `v1.13.4`.
#     The default resolves to nothing. Hence it sits in requiredSubstitutions.
#  2. The artifact patches MACHINERY_CONFIG=/etc/machinery/config.json onto the
#     deployment and mounts the `machinery-config` ConfigMap — which carries
#     only LOG_LEVEL. There is no config.json key, so the path dangles. The
#     service does run (the config is optional; it falls back to built-in
#     defaults), but the WATCH SET cannot be configured through the app today.
#
# That second one matters for this fleet: the watch set decides which kinds the
# dashboard shows, and no shipped example covers ours. examples/configs/
# platforms.json watches StoragePlatform / NetworkIntegration /
# SecurityPlatform / AnsibleRun — not ClusterStack, Platform or XIPReservation.
# Making those visible needs a config the artifact has no way to supply yet.
machinery: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/apps/machinery"
    defaultVersion = "v1.18.1"
    components = [
        s.Component {
            name = "app"
            path = "./"
            wrapsHelmRelease = True
            timeout = "15m"
            # MACHINERY_VERSION is listed even though the artifact gives it a
            # default, because that default is WRONG: it reads `1.13.4` while
            # the published tags are `v1.13.4` — the OCIRepository does not
            # resolve and the app never deploys. Declaring it required turns a
            # silent pull failure into a render-time rejection that names the
            # variable. Drop it from this list once flux fixes the default.
            #
            # MACHINERY_HOSTNAME (machinery), MACHINERY_NAMESPACE (machinery)
            # and GATEWAY_NAMESPACE (default) carry usable defaults.
            requiredSubstitutions = ["DOMAIN", "GATEWAY_NAME", "MACHINERY_VERSION"]
            # DOMAIN is the cluster's own — the same value the Gateway listener
            # wildcard and the certificate CN are built from. GATEWAY_NAME stays
            # manual: which Gateway a service attaches to is a decision.
            substitutionSources = {
                DOMAIN = "ipReservation.domain"
            }
        }
    ]
}
