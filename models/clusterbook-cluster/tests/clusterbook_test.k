# Tests for the clusterbook CRD schemas
import ..v1alpha1.clusterbook_stuttgart_things_com_v1alpha1_clusterbook_cluster as cbk_mod

# Test 1: ClusterbookCluster renders with kubeconfigSecretRef (managed mode)
test_clusterbook_cluster_managed = lambda {
    cluster = cbk_mod.ClusterbookCluster {
        metadata = {
            name = "philly"
        }
        spec = {
            networkKey = "10.31.101"
            clusterName = "philly"
            createDNS = True
            preserveKubeconfigServer = True
            kubeconfigSecretRef = {
                name = "philly"
                namespace = "argocd"
            }
            providerConfigRef = {
                name = "default"
            }
            argocdNamespace = "argocd"
            labels = {
                "env" = "lab"
                "role" = "mgmt"
                "auto-project" = "true"
            }
            releaseOnDelete = True
        }
    }

    assert cluster.apiVersion == "clusterbook.stuttgart-things.com/v1alpha1"
    assert cluster.kind == "ClusterbookCluster"
    assert cluster.metadata.name == "philly"
    assert cluster.spec.clusterName == "philly"
    assert cluster.spec.networkKey == "10.31.101"
    assert cluster.spec.createDNS == True
    assert cluster.spec.preserveKubeconfigServer == True
    assert cluster.spec.kubeconfigSecretRef.name == "philly"
    assert cluster.spec.kubeconfigSecretRef.namespace == "argocd"
    assert cluster.spec.providerConfigRef.name == "default"
    assert cluster.spec.argocdNamespace == "argocd"
    assert cluster.spec.labels["env"] == "lab"
    assert cluster.spec.releaseOnDelete == True
}

# Test 2: ClusterbookCluster renders with existingSecretRef (enrich mode) and useFQDNAsServer
test_clusterbook_cluster_enrich = lambda {
    cluster = cbk_mod.ClusterbookCluster {
        metadata = {
            name = "denver"
        }
        spec = {
            networkKey = "10.31.103"
            clusterName = "denver"
            createDNS = True
            useFQDNAsServer = True
            serverSubdomain = "api"
            serverPort = 6443
            existingSecretRef = {
                name = "denver-cluster"
                namespace = "argocd"
            }
            providerConfigRef = {
                name = "default"
            }
        }
    }

    assert cluster.spec.useFQDNAsServer == True
    assert cluster.spec.serverSubdomain == "api"
    assert cluster.spec.serverPort == 6443
    assert cluster.spec.existingSecretRef.name == "denver-cluster"
    assert cluster.spec.existingSecretRef.namespace == "argocd"
}

# Test 3: ClusterbookCluster in kind / registration-only mode
# (no networkKey, no providerConfigRef, with clusterType=kind, lbRange,
# and kubeconfigSecretRef.key)
test_clusterbook_cluster_kind = lambda {
    cluster = cbk_mod.ClusterbookCluster {
        metadata = {
            name = "dev"
        }
        spec = {
            clusterName = "dev"
            clusterType = "kind"
            preserveKubeconfigServer = True
            kubeconfigSecretRef = {
                name = "kind-dev-kubeconfig"
                namespace = "argocd"
                key = "kubeconfig"
            }
            argocdNamespace = "argocd"
            lbRange = {
                start = "172.18.255.200"
                stop = "172.18.255.250"
            }
            labels = {
                "auto-project" = "true"
                "cicd-platform" = "true"
            }
            releaseOnDelete = True
        }
    }

    assert cluster.spec.clusterType == "kind"
    assert cluster.spec.kubeconfigSecretRef.key == "kubeconfig"
    assert cluster.spec.lbRange.start == "172.18.255.200"
    assert cluster.spec.lbRange.stop == "172.18.255.250"
    assert cluster.spec.preserveKubeconfigServer == True
}

# Run all tests
test_clusterbook_cluster_managed()
test_clusterbook_cluster_enrich()
test_clusterbook_cluster_kind()

print("All clusterbook schema tests passed")
