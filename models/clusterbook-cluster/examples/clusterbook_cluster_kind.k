"""
Example: ClusterbookCluster in kind / registration-only mode.

No networkKey + no providerConfigRef → clusterbook-operator skips
clusterbook-server calls entirely and only writes the ArgoCD cluster Secret
with cluster-type=kind plus user-pinned lb-range-{start,stop} annotations
(typically consumed by a CiliumLoadBalancerIPPool on the kind cluster).

preserveKubeconfigServer is required by the CRD in this mode — there is no
allocated IP/FQDN, so data.server is taken from the kubeconfig verbatim.

Render:
    kcl run examples/clusterbook_cluster_kind.k
"""
import ..v1alpha1.clusterbook_stuttgart_things_com_v1alpha1_clusterbook_cluster as cbk_mod

# Inputs (override via -D key=value)
clusterName = option("clusterName") or "dev"
kubeconfigSecretName = option("kubeconfigSecretName") or "kind-${clusterName}-kubeconfig"
kubeconfigSecretKey = option("kubeconfigSecretKey") or "kubeconfig"
argocdNamespace = option("argocdNamespace") or "argocd"
lbRangeStart = option("lbRangeStart") or "172.18.255.200"
lbRangeStop = option("lbRangeStop") or "172.18.255.250"

cluster = cbk_mod.ClusterbookCluster {
    metadata = {
        name = clusterName
    }
    spec = {
        clusterName = clusterName
        clusterType = "kind"
        preserveKubeconfigServer = True
        kubeconfigSecretRef = {
            name = kubeconfigSecretName
            namespace = argocdNamespace
            key = kubeconfigSecretKey
        }
        argocdNamespace = argocdNamespace
        lbRange = {
            start = lbRangeStart
            stop = lbRangeStop
        }
        labels = {
            "auto-project" = "true"
            "cicd-platform" = "true"
            "cicd-platform/crossplane" = "true"
            "cicd-platform/openebs" = "true"
            "cicd-platform/kro" = "true"
            "cicd-platform/tekton" = "true"
            "cicd-platform/argo-rollouts" = "false"
            "cicd-platform/dapr" = "false"
            "cicd-platform/kargo" = "false"
        }
        releaseOnDelete = True
    }
}

items = [cluster]
