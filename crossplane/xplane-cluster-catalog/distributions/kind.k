# kind — a Kubernetes-in-Docker cluster on a provisioned VM.
#
# Mirrors what nativevspherevm-kind-test1.yaml runs today.
import ..schema as s

kind: s.Distribution = s.Distribution {
    playbooks = ["sthings.container.kind"]
    vars = {
        install_kind = "true"
        create_kind_cluster = "true"
        # PINNED — but note what is pinned: kind takes a KIND BINARY version,
        # not a Kubernetes version (the k8s version comes from the node image
        # that binary defaults to). This is why the catalog pins per
        # distribution rather than exposing one `kubernetesVersion` field: the
        # two distributions genuinely pin different things, and a shared field
        # would be a lie for one of them.
        kind_version = "0.31.0"
        kubectl_version = "1.35.0"
        # false, so re-reconciles are idempotent instead of destroying and
        # rebuilding the cluster (and moving the API port) on every run.
        rebuild_kind_cluster = "false"
        # `kind export kubeconfig` emits 0.0.0.0, which the API server
        # certificate is not valid for — rewrite it to the VM's external IP.
        update_kubeconfig_ip = "true"
        fetch_kubeconfig = "true"
        ansible_become = "true"
        ansible_become_method = "sudo"
    }
    # THE CLUSTER NAME DOES NOT ARRIVE AS `cluster_name`. The kind play reads
    # `kind_cluster_name` and defaults it to `dev`; `cluster_name` reaches only
    # the upload play, where it is the Vault secret name. Without this the
    # cluster is called `dev` no matter what the XR asked for, and the Cni
    # child's k8sServiceHost (`<clusterName>-control-plane`) names a container
    # that was never created — see crossplane-configurations#232 and the field
    # docs on Distribution.clusterNameVars.
    clusterNameVars = ["kind_cluster_name"]
    # The kind role targets the VM directly; no master/worker split (the kind
    # NODES are containers on that one VM, expressed via count_* vars).
    inventoryGroups = ["all"]
    # kind is built deliberately WITHOUT a CNI, so the Platform's Cni component
    # is required — the mirror image of k3s.
    cniOwnership = "platform"
    multiNode = False
}
