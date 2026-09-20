"""
k3s as a RANCHER custom-node cluster: Rancher creates the cluster, a node joins
it with the registration command Rancher publishes, and the join play uploads
that node's admin kubeconfig to Vault.

The twin of rancher_rke2. Everything is the same — one join stage, the CNI from
the Platform, one node — EXCEPT `machineGlobalConfig`, whose keys are the
server's, and k3s and rke2 do not share them.

REFERENCE RUN (the rule this catalog keeps: no entry without one):
`schmetterpause-rehearsal1`, run 3, on u26-kind3, 2026-09-20 — and it is a
reference run of the FAILURE this entry exists to prevent, which is worth more
than a green one here. With `distribution: rancher-rke2` against environment
`rancher-join-test` (distro k3s, v1.36.4+k3s1), Rancher provisioned k3s and got:

    cilium-agent: creating vxlan device cilium_vxlan: failed to set link up:
                  address already in use
    cilium status: [ens18 ..., flannel.1 10.42.0.0 ...]
    coredns: dial tcp 10.43.0.1:443: connect: network is unreachable
    cattle-cluster-agent: CrashLoopBackOff, could not resolve rancher...
    Rancher: waiting for cluster agent to connect
    kube-system: helm-install-traefik CrashLoopBackOff

k3s ignored every rke2 key, so flannel and traefik stayed, cilium could not
create its own vxlan device, and NOTHING that needs a pod network ever worked.
The cluster looked healthy for ten minutes and never registered. See
stuttgart-things/kcl#282.

WHY THE CNI CANNOT COME FROM RANCHER OR FROM THE PLAY: unchanged from
rancher_rke2 — everything Rancher offers goes through its proxy, and that proxy
needs `cattle-cluster-agent`, an ordinary Deployment on the pod network.
"""

import ..schema as s

rancher_k3s: s.Distribution = s.Distribution {
    # Same single stage as rancher_rke2: the play registers the node AND
    # uploads the kubeconfig.
    playbooks = ["sthings.rke.rancher_register"]
    vars = {
        rancher_upload_kubeconfig = "true"
        # Empty = the play detects k3s or rke2 (#277). Named here rather than
        # left out, because a reader comparing the two entries should see that
        # this is deliberate in both.
        rancher_kubeconfig_path = ""
    }
    inventoryGroups = ["all"]
    cniOwnership = "platform"
    multiNode = False
    provisioner = "rancher"

    machineGlobalConfig = {
        # THE WHOLE REASON THIS ENTRY EXISTS. k3s names its switches
        # differently, and an unknown key is IGNORED rather than refused:
        #
        #   rke2                          k3s
        #   cni: none                     flannel-backend: none
        #                                 + disable-network-policy: true
        #   ingress-controller: none      disable: [traefik]
        #   disable: [rke2-traefik-crd]   disable: [traefik, servicelb]
        #
        # The same three the ansible k3s role writes (distributions/k3s.k), for
        # the same reason: the cluster comes up deliberately without a CNI.
        "flannel-backend" = "none"
        "disable-network-policy" = True
        # Cilium runs with kubeProxyReplacement, which L2 announcements and
        # Gateway API both require.
        "disable-kube-proxy" = True
        # traefik is k3s's bundled ingress and servicelb its bundled
        # LoadBalancer; cilium's Gateway and cilium-lb replace both. Left on,
        # traefik's helm-install job also crashloops until a CNI exists.
        disable = ["traefik", "servicelb"]
    }

    # Identical to rancher_rke2: single node, so cilium reaches the API server
    # on the node itself, and the Cni owns the Gateway API CRDs.
    cniDefaults = {
        cilium = {
            kubeProxyReplacement = True
            k8sServiceHost = "127.0.0.1"
            k8sServicePort = 6443
        }
        gatewayAPI = {enabled = True}
        values = {
            l2announcements = {enabled = True}
            externalIPs = {enabled = True}
            hubble = {
                enabled = True
                relay = {enabled = True}
                ui = {enabled = True}
            }
        }
    }
}
