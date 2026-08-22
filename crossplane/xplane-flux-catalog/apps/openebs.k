import ..schema as s

# openebs — https://github.com/stuttgart-things/flux/tree/main/infra/openebs
#
# The fleet's local-storage provisioner. Installed for exactly one thing: the
# `openebs-hostpath` StorageClass. Every other engine the chart can ship — lvm,
# zfs, mayastor, rawfile — is off in the artifact.
#
# NO REQUIRED SUBSTITUTIONS, which is unusual here and the reason this is a good
# first storage entry: every variable in the artifact carries a manifest default,
# so `apps: {openebs: {enabled: true}}` is a complete spec. Contrast headlamp,
# which needs DOMAIN/HOSTNAME/GATEWAY_NAME and a Gateway that already exists.
#
# NO dependsOn. It installs before anything and depends on nothing — which is
# also why it is worth having early: several catalogued-adjacent apps (vault,
# prometheus, harbor, keycloak) default their PVCs to a StorageClass that has to
# come from somewhere.
#
# VERSION IS THE FLUX ARTIFACT TAG, NOT THE CHART VERSION. v1.19.1 is the first
# release carrying flux#192; the openebs chart it installs is pinned separately
# inside the artifact (OPENEBS_VERSION, default 4.2.0).
#
# THAT DISTINCTION IS LOAD-BEARING HERE. `OPENEBS_VERSION` is substitutable from
# the XR, and the chart changes shape between 4.2 and 4.5:
#
#   loki   6.29.0  condition loki.enabled   — added in 4.5, DEFAULT TRUE
#   alloy  1.0.1   condition alloy.enabled  — added in 4.5, DEFAULT TRUE
#   localpv-provisioner  became conditional on engines.local.hostpath.enabled
#
# Before flux#192 the artifact had no keys for any of those, so raising
# OPENEBS_VERSION would have silently deployed a Loki StatefulSet, the MinIO
# StatefulSet backing it (MinIO is Loki's object store, a sub-dependency with no
# toggle of its own), an Alloy DaemonSet and two extra StorageClasses — and on a
# small cluster Loki cannot even schedule, wanting three replicas with pod
# anti-affinity. Pinning v1.19.1 or later is what makes an OPENEBS_VERSION bump
# safe rather than a surprise.
openebs: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/infra/openebs"
    # v1.24.0 makes openebs-hostpath the DEFAULT StorageClass
    # (stuttgart-things/flux#198). rke2 ships no default at all, so every
    # cluster that installed openebs still had none, and every PVC that did not
    # name a class stayed Pending. Found through Tekton, of all things: its
    # Results component wants a PostgreSQL, the PVC hung, the operator blocked
    # on it, and the Dashboard never appeared. Nothing in that failure named
    # storage. Do not pin below v1.24.0.
    defaultVersion = "v1.24.0"
    components = [
        s.Component {
            name = "install"
            # Single-Kustomization artifact: requirements.yaml (Namespace +
            # HelmRepository) and release.yaml sit at the root, so there is
            # nothing under ./components to address.
            path = "./"
            wrapsHelmRelease = True
            # The chart pulls five subcharts and runs a pre-upgrade hook; 10m is
            # not enough on a cold node.
            timeout = "15m"
        }
    ]
}
