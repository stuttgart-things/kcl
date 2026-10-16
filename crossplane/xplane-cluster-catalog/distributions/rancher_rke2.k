"""
rke2 as a RANCHER custom-node cluster: Rancher creates the cluster, a node joins
it with the registration command Rancher publishes, and the join play uploads
that node's admin kubeconfig to Vault.

REFERENCE RUN (the rule this catalog keeps: no entry without one):
`rancher-join-test4` on u26-kind3, 2026-09-15 — RancherCluster v0.8.1 +
NativeProxmoxVM v0.15.0 with sthings.rke.rancher_register from
sthings-rke-26.915.1292, rke2 v1.36.4+rke2r1, one node.

THE NAME SAYS rke2, THE ENTRY DOES NOT REQUIRE IT. The distribution comes from
the RancherCluster's EnvironmentConfig — `rancher-join-test` provisions k3s —
and everything here is the same either way EXCEPT the admin kubeconfig path,
which is why that one is detected rather than pinned (see below, #277). Verified end to end:
the play finished with failed=0, the node registered, its kubeconfig landed in
`kubeconfigs/rancher-join-test4`, a Cni XR installed cilium 1.19.6 through the
node kubeconfig, and only THEN did `cattle-cluster-agent` start and Rancher
report Connected. Afterwards: Argo CD registration with a clusterbook IP, a
Vault-signed certificate, and an L2-announced LoadBalancer answering from
another subnet. See crossplane-configurations#422 and #438.

WHY THE CNI CANNOT COME FROM RANCHER OR FROM THE PLAY:
Everything Rancher offers goes through its proxy, and that proxy needs
`cattle-cluster-agent` — an ordinary Deployment on the pod network. With no CNI
that pod stays Pending, so the Rancher kubeconfig answers 403 (measured) and
the cluster is reachable only through the node's own kubeconfig. Hence
cniOwnership "platform": the Cni XR installs cilium past Rancher.
"""

import ..schema as s

rancher_rke2: s.Distribution = s.Distribution {
    # One stage, not two: the play registers the node AND uploads the
    # kubeconfig, because both need the same node and the same moment.
    playbooks = ["sthings.rke.rancher_register"]
    vars = {
        rancher_upload_kubeconfig = "true"
        # EMPTY = LET THE PLAY DETECT IT, and that is not a convenience.
        #
        # This entry used to pin /etc/rancher/rke2/rke2.yaml, from its own
        # reference run. But on a CUSTOM NODE the distribution belongs to the
        # Rancher cluster the node joins, not to this catalog: the same
        # registration command installs k3s or rke2, and which one is decided
        # by the RancherCluster's EnvironmentConfig — which this entry cannot
        # read. Pinning it here is a guess about somebody else's cluster.
        #
        # The wrong guess is expensive: the play waits the full
        # rancher_kubeconfig_wait_timeout (900 s) and fails on the LAST task of
        # a run that did everything else right. Measured 2026-09-19 with
        # environment rancher-join-test (distro k3s), which is the
        # configuration the fleet uses today: stuttgart-things/kcl#277.
        #
        # NEEDS sthings.rke with stuttgart-things/ansible#1227, where an empty
        # path polls both candidates. Against an older collection an empty path
        # fails immediately rather than after 15 minutes — loudly, and on the
        # first run, which is the failure mode to prefer.
        rancher_kubeconfig_path = ""
    }
    # The registration command carries the node roles, so a flat inventory is
    # enough — unlike deploy_configure_rke, which branches on master groups.
    inventoryGroups = ["all"]
    cniOwnership = "platform"
    # Multi-node since catalog 0.11.0 (crossplane-configurations#170), in the
    # narrowest shape that answers decision 1.2/1.3 of #438:
    #
    #   - EVERY node carries all three roles (etcd, control-plane, worker), so
    #     the per-node role flags are all true and need no per-node decision.
    #   - the kubeconfig upload runs on exactly ONE node -- the first, whose
    #     join is today's single-node join, unchanged. Nodes 2..N join with
    #     rancher_upload_kubeconfig false (xplane-cluster >= 0.26.0).
    #   - the API address stays 127.0.0.1 for cilium (cniDefaults below), and
    #     that holds on every node for the same reason: each one runs its own
    #     API server.
    #
    # Worker-only nodes are future work: they run no API server, so cilium
    # needs an address every node can reach (a VIP or DNS, #171) first.
    #
    # NO MULTI-NODE REFERENCE RUN YET, which this catalog normally asks for
    # before a flag like this. Opened on the single-node reference runs above
    # plus the join play's own role flags (all default true), so the first
    # three-node build (the LabDA app cluster) is that run -- record it here.
    multiNode = True
    provisioner = "rancher"
    # What the EnvironmentConfig of a matching rancher environment must say.
    serverDistro = "rke2"

    machineGlobalConfig = {
        # No CNI from rke2: never rke2-cilium (see the fleet note
        # crossplane/knowledge/cilium-not-via-rancher-helm.md), and no calico or
        # canal either — the Cni XR owns this.
        cni = "none"
        # Cilium runs with kubeProxyReplacement, which L2 announcements and
        # Gateway API both require.
        "disable-kube-proxy" = True
        # Since rke2 v1.36 traefik is the default ingress; Cilium's Gateway
        # replaces it. This is the documented switch — chart names under
        # `disable` are not.
        "ingress-controller" = "none"
        # The bundled Gateway API CRDs arrive AFTER the CNI (helm-install jobs
        # need a pod network) and at rke2's pin — v1.5.1 on v1.36.4, which pairs
        # with neither cilium 1.19 (1.4.1) nor 1.20 (1.6.1). The Cni installs
        # them itself, so rke2's copy has to stay away or the two Helm owners
        # collide. The chart name moved between rke2 versions, hence both.
        disable = ["rke2-traefik-crd", "rke2-gateway-api-crd"]
    }

    cniDefaults = {
        cilium = {
            kubeProxyReplacement = True
            # Cilium reaches the API server on the node itself, and the value
            # survives a DHCP lease change. Holds on a multi-node cluster too,
            # because every node is a control-plane node and runs an API
            # server. A worker-only node does not: it needs an address every
            # node can reach (VIP or DNS, crossplane-configurations#171).
            k8sServiceHost = "127.0.0.1"
            k8sServicePort = 6443
        }
        # CRDs first, then cilium — the module gates on it.
        gatewayAPI = {enabled = True}
        values = {
            # What the network-platform profile expects: cilium-lb announces
            # LoadBalancer IPs over L2.
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
