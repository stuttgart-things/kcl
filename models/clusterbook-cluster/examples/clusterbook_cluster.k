"""
Example: ClusterbookCluster reserving an IP/DNS record and producing an
ArgoCD cluster Secret from a referenced kubeconfig Secret.

Render:
    kcl run examples/clusterbook_cluster.k
"""
import ..v1alpha1.clusterbook_stuttgart_things_com_v1alpha1_clusterbook_cluster as cbk_mod

# Inputs (override via -D key=value)
clusterName = option("clusterName") or "philly"
networkKey = option("networkKey") or "10.31.101"
kubeconfigSecretName = option("kubeconfigSecretName") or clusterName
argocdNamespace = option("argocdNamespace") or "argocd"

cluster = cbk_mod.ClusterbookCluster {
    metadata = {
        name = clusterName
    }
    spec = {
        networkKey = networkKey
        clusterName = clusterName
        createDNS = True
        preserveKubeconfigServer = True
        kubeconfigSecretRef = {
            name = kubeconfigSecretName
            namespace = argocdNamespace
        }
        providerConfigRef = {
            name = "default"
        }
        argocdNamespace = argocdNamespace
        labels = {
            "env" = "lab"
            "role" = "mgmt"
            "auto-project" = "true"
        }
        releaseOnDelete = True
    }
}

items = [cluster]
