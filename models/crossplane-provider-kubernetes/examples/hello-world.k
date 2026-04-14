"""
Hello World examples for Crossplane Kubernetes Provider.

Shows both the cluster-scoped `kubernetes.crossplane.io/v1alpha2 Object` and the
Crossplane v2 namespaced `kubernetes.m.crossplane.io/v1alpha1 Object`, each
managing a simple ConfigMap.
"""

import ..v1alpha2 as k8sv2
import ..v1alpha1.kubernetesm as k8sm

# Cluster-scoped Object (kubernetes.crossplane.io/v1alpha2)
helloWorldObject: k8sv2.Object = {
    metadata = {
        name = "hello-world-cm"
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = "hello-world"
                    namespace = "default"
                }
                data = {
                    greeting = "hello"
                }
            }
        }
        providerConfigRef = {
            name = "default"
        }
    }
}

# Namespaced Object (kubernetes.m.crossplane.io/v1alpha1) — Crossplane v2 style
helloWorldNamespacedObject: k8sm.Object = {
    metadata = {
        name = "hello-world-cm-ns"
        namespace = "default"
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = "hello-world-ns"
                    namespace = "default"
                }
                data = {
                    greeting = "hello"
                }
            }
        }
        providerConfigRef = {
            kind = "ClusterProviderConfig"
            name = "default"
        }
    }
}
