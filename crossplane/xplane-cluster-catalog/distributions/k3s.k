# k3s — single-node today.
#
# Every var here is load-bearing; see the header of
# stuttgart-things/crossplane xrs/ansiblerun/labul/kind1/ansiblerun-k3s-u26-kind1.yaml
# for the incident history behind them.
import ..schema as s

k3s: s.Distribution = s.Distribution {
    playbooks = ["sthings.rke.k3s_cluster"]
    vars = {
        install_k3s = "true"
        k3s_state = "present"
        # PINNED. Without these the role installs whatever its own default is —
        # a live build produced v1.36.1 while the hand-written XR this catalog
        # replaces pins 1.35.1, so two clusters from the same profile could
        # differ by build date. A profile that does not pin its Kubernetes
        # version is not really a profile.
        k3s_k8s_version = "1.35.1"
        k3s_release_kind = "k3s1"
        cluster_setup = "singlenode"
        # MANDATORY. The role's k3s_config default writes flannel-backend=none,
        # disable-kube-proxy=true and disable-network-policy=true — k3s comes up
        # deliberately without a CNI and without kube-proxy. With this false the
        # cluster has no working pod network at all.
        install_cilium = "true"
        prepare_rancher_ha_nodes = "true"
        install_helm_diff = "false"
        # Fetched to the ansible controller, i.e. the Tekton pod's ephemeral
        # filesystem. On the node it stays at /etc/rancher/k3s/k3s.yaml with the
        # API server address rewritten to the VM IP.
        fetched_kubeconfig_path = "/tmp/kubeconfig"
        ansible_become = "true"
        ansible_become_method = "sudo"
    }
    inventoryGroups = ["initial_master_node", "additional_master_nodes", "workers"]
    # The role installs cilium itself (see install_cilium above), so a Platform
    # for a k3s cluster must leave cni.enabled off.
    cniOwnership = "self"
    # cluster_setup would have to become "multinode" and the groups populated
    # from N VM IPs. Not verified in this fleet yet -> #170.
    multiNode = False
}
