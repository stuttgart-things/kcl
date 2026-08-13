import ..schema as s

# cilium — https://github.com/stuttgart-things/flux/tree/main/infra/cilium
#
# CONFIGURATION ONLY. This entry does NOT install Cilium: the artifact's root
# kustomization pulls exactly `components/lb` and `components/gateway`, and the
# component is named `config` for that reason. `components/install` sits beside
# them and is deliberately NOT part of the root — on a cluster whose CNI is
# already Cilium (every rke2 built by the cluster Configuration) a second
# install would put two CNIs on one datapath.
#
# There is consequently no `install` component here to depend on, and none
# should be added: a cluster that needs Cilium INSTALLED is served by the
# bootstrap/cilium Configuration instead.
#
# Both pieces are kustomize `kind: Component`, not standalone Kustomizations,
# so they cannot be split into two Flux Kustomizations — lb and gateway arrive
# together or not at all. Worth knowing because the gateway's TLS listener
# needs a certificate that a fresh cluster does not have yet: the HTTP listener
# works immediately, HTTPS stays certificate-less until something issues into
# CILIUM_GATEWAY_TLS_SECRET.
#
# Prerequisite is a cluster fact rather than a catalog dependency: Cilium must
# already run WITH Gateway API and L2 announcements enabled
# (`enable-gateway-api=true`, `enable-l2-announcements=true`, the
# `ciliumloadbalancerippools` CRD registered). The rke2 role brings that; a
# cluster without it gets Kustomizations that apply CRs whose CRDs do not
# exist.
cilium: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/infra/cilium"
    defaultVersion = "v1.18.1"
    components = [
        s.Component {
            name = "config"
            path = "./"
            # All four are used without a `:=` default, so Flux would silently
            # substitute an empty string: an IP pool with blank bounds and a
            # Gateway with a blank hostname both apply cleanly and do nothing
            # useful. START/STOP and DOMAIN come from a clusterbook reservation
            # (the ip-reservation Configuration publishes both on its XR
            # status); TLS_SECRET from whatever issues the wildcard cert.
            requiredSubstitutions = [
                "CILIUM_LB_IP_START"
                "CILIUM_LB_IP_STOP"
                "CILIUM_GATEWAY_DOMAIN"
                "CILIUM_GATEWAY_TLS_SECRET"
            ]
        }
    ]
}
