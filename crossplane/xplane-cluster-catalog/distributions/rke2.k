# rke2 — single-node through this catalog.
#
# Added only after a reference run, as main.k demanded. That run, on
# 2026-08-11, was an AnsibleRun on the u26-kind3 machinery cluster driving
# sthings.rke.rke2_cluster against a Proxmox VM u26-kind3 had itself built and
# base-OS'd (VMID 132, 10.31.102.147). Result:
#
#   rke2-server                    active
#   u26-baseos-test.labul.sva.de   Ready   control-plane,etcd   v1.35.1+rke2r1
#   cilium                         3 pods
#
# Every value below is what that run used. None of it is copied from the play's
# defaults.
import ..schema as s

rke2: s.Distribution = s.Distribution {
    playbooks = ["sthings.rke.rke2_cluster"]
    vars = {
        rke_state = "present"
        # PINNED, AND DELIBERATELY NOT THE PLAY DEFAULT. sthings.rke.rke2_cluster
        # defaults to 1.36.1 / rke2r2, but every rke2 cluster this fleet runs is
        # on 1.35.1 / rke2r1 (exec/labul/{infra,platform,sthings-infra}-rke2 all
        # agree). Shipping the play default here would pin a combination nobody
        # in this fleet has ever booted — the same trap distributions/k3s.k
        # already records, where a live build produced v1.36.1 against an XR
        # pinning 1.35.1. The reference run used the pair below and came up
        # Ready; that is the only reason it is here.
        rke2_k8s_version = "1.35.1"
        rke2_release_kind = "rke2r1"
        cluster_setup = "singlenode"
        # MANDATORY PAIR, and the whole reason cniOwnership is "self". rke2 is
        # told to ship no CNI at all, so the role must install cilium itself.
        # Drop install_cilium and the cluster has no pod network; let a Platform
        # add its own Cni component on top and two CNIs fight over the datapath.
        rke2_cni = "none"
        install_cilium = "true"
        # Cilium replaces kube-proxy, matching the CNI-less config above.
        disableKubeProxy = "true"
        # The role's own install path in this fleet — every exec/labul/*rke2*
        # vars.yaml sets it. Not an airgap statement about the environment.
        rke2_airgapped_installation = "true"
        prepare_rancher_ha_nodes = "true"
        install_helm_diff = "false"
        # Fetched to the ansible controller, i.e. the Tekton pod's ephemeral
        # filesystem. On the node the kubeconfig stays at
        # /etc/rancher/rke2/rke2.yaml.
        fetched_kubeconfig_path = "/tmp/kubeconfig"
        ansible_become = "true"
        ansible_become_method = "sudo"
    }
    # Same role as k3s (sthings.rke.deploy_configure_rke), so the same three
    # groups: it branches on groups['initial_master_node'] and
    # groups['additional_master_nodes'], and a flat `all+[...]` inventory fails
    # with an undefined-group error.
    inventoryGroups = ["initial_master_node", "additional_master_nodes", "workers"]
    # The role installs cilium (see the pair above), so a Platform for an rke2
    # cluster must leave cni.enabled off.
    cniOwnership = "self"
    # NOT a statement about rke2 upstream — the fleet runs multinode rke2 today
    # through ansible (exec/labul/sthings-infra-rke2 sets cluster_setup:
    # multinode). It is a statement about THIS path: a ClusterStack composes one
    # VM child, so N masters would need N VMs, static addressing and an
    # aggregate ready gate. Same open item as k3s -> #170.
    multiNode = False
    # clusterNameVars stays empty: sthings.rke.rke2_cluster reads `cluster_name`
    # directly (`cluster_name: "{{ cluster_name | default('rke2') }}"`), unlike
    # sthings.container.kind, which ignores it and needs kind_cluster_name.
}
