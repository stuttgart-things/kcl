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
# lb and gateway are shipped as one component here, not because they must be:
# both are kustomize `kind: Component`, and this entry claimed for months that
# a Component therefore cannot be a Flux Kustomization of its own. That is
# WRONG — `kustomize build` on a Component directory works, and Flux runs
# nothing else. Verified 2026-08-17 against all four tekton components and both
# cilium ones.
#
# They stay together because they belong together — an L2 pool without a
# Gateway announces nothing, a Gateway without a pool has no address — not
# because kustomize forces it. Splitting them is available if a reason appears.
#
# Worth knowing either way: the gateway's TLS listener needs a certificate a
# fresh cluster does not have yet. The HTTP listener works immediately, HTTPS
# stays certificate-less until something issues into CILIUM_GATEWAY_TLS_SECRET.
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
                "CILIUM_GATEWAY_NAME"
            ]
            # Three of the four are FACTS the platform already discovered, and
            # repeating them on the XR is how they drift: when the reservation
            # moved from a standalone XR to a platform child on u26-rke2-1 the
            # IP changed .5 -> .8, DNS followed immediately and the Gateway did
            # not, because its bounds were typed in by hand.
            #
            # Start and stop both take the single reserved address: `count: 1`
            # reserves one IP and the pool is that one address, not a range.
            #
            # TLS_SECRET is NOT listed on purpose. It is not a discovered fact
            # but a decision about where a certificate gets issued, and nothing
            # in the platform's status can answer it.
            substitutionSources = {
                CILIUM_LB_IP_START = "ipReservation.ipAddresses[0]"
                CILIUM_LB_IP_STOP = "ipReservation.ipAddresses[0]"
                CILIUM_GATEWAY_DOMAIN = "ipReservation.domain"
                # NOT in requiredSubstitutions: the artifact defaults it to
                # `cilium-gateway`, so leaving it unset is harmless. It is listed
                # here so the value the platform PUBLISHES is also the value the
                # Gateway is CREATED with — otherwise the same default would live
                # in two repositories and drift the first time one moved.
                #
                # This is what makes the name discoverable for everything else:
                # machinery and headlamp read the identical `gateway.name`, so a
                # cluster that renames its Gateway renames it everywhere at once.
                CILIUM_GATEWAY_NAME = "gateway.name"
            }
        }
    ]
}
