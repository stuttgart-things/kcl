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
# Two gaps used to make this entry awkward; stuttgart-things/flux#193 closed
# both in artifact v1.19.2, which is why this pins it rather than v1.18.1:
#
#  1. MACHINERY_VERSION defaulted to `1.13.4` while the published tags read
#     `v1.13.4`, so the OCIRepository never resolved and the app never
#     deployed. The entry carried it in requiredSubstitutions to turn that
#     silent pull failure into a render-time rejection; no longer needed.
#  2. MACHINERY_CONFIG pointed at /etc/machinery/config.json while the mounted
#     ConfigMap held only LOG_LEVEL, so the WATCH SET — which decides the kinds
#     the dashboard shows — could not be configured through the app at all. The
#     service still ran, on built-in defaults watching StoragePlatform and
#     NetworkIntegration: a dashboard, just not this fleet's.
#
# The artifact now ships the watch set as a file, covering ClusterStack,
# Platform, XIPReservation, VaultK8sAuth and — since v1.22.0 — NativeProxmoxVM,
# NativeVsphereVM and AnsibleRun. Enabling this app is therefore enough; no
# ConfigMap has to be placed on the cluster by hand.
#
# v1.22.0 added the last three because four kinds was too few to see what a
# build is doing: a ClusterStack shows its stage, but the VM it waits on and the
# AnsibleRun that provisions it were both invisible — exactly what one opens
# kubectl for when a build sits at `stage: vm`. AnsibleRun also surfaces its
# pipelineRunName, which is how the Tekton logs are found
# (stuttgart-things/flux#201).
#
# v1.19.3 adds the RBAC to actually READ those kinds (stuttgart-things/flux#195).
# The watch set lived in the flux artifact while the ClusterRole lived in the
# machinery kustomize base — a different repository — so #193 changed what the
# app looks at without changing what it may read. On the first deploy through
# this catalog the Deployment was 1/1, the HTTPRoute attached and HTTPS answered
# in 79ms, while every request was a 500 and every informer sat on
# `clusterstacks... is forbidden`. Do not pin below v1.19.3.
machinery: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/apps/machinery"
    defaultVersion = "v1.22.0"
    components = [
        s.Component {
            name = "app"
            path = "./"
            wrapsHelmRelease = True
            timeout = "15m"
            # MACHINERY_VERSION is no longer listed: stuttgart-things/flux#193
            # fixed the artifact's default (it read `1.13.4` while the published
            # tags read `v1.13.4`, so the OCIRepository never resolved) and this
            # entry pins v1.19.2, which carries that fix. Overriding the version
            # is still possible, it is just no longer mandatory.
            #
            # MACHINERY_HOSTNAME (machinery), MACHINERY_NAMESPACE (machinery)
            # and GATEWAY_NAMESPACE (default) carry usable defaults too.
            requiredSubstitutions = ["DOMAIN", "GATEWAY_NAME"]
            # Both are facts about the cluster now. DOMAIN is its own — the
            # same value the Gateway listener wildcard and the certificate CN are
            # built from. GATEWAY_NAME used to be called a decision and typed by
            # hand; it is the name the platform SETS on the Gateway it creates
            # (cilium reads the identical `gateway.name`), so stating it again
            # was only a chance to state it differently. Enabling this app now
            # costs no typed value at all.
            substitutionSources = {
                DOMAIN = "ipReservation.domain"
                # No longer a required substitution: the platform publishes the
                # Gateway's name it also creates it with, so nobody states it.
                GATEWAY_NAME = "gateway.name"
            }
        }
    ]
}
