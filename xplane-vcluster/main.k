import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as obj

# --- Get XR spec fields ---
name = option("params")?.oxr?.spec?.name or "test"
version = option("params")?.oxr?.spec?.version or "0.29.0"
chartName = option("params")?.oxr?.spec?.chartName or "vcluster"
repository = option("params")?.oxr?.spec?.repository or "https://charts.loft.sh"
clusterName = option("params")?.oxr?.spec?.clusterName or "kind"
targetNamespace = option("params")?.oxr?.spec?.targetNamespace or "vcluster"

# VCluster specific configuration
storageClass = option("params")?.oxr?.spec?.storageClass or "standard"
bindAddress = option("params")?.oxr?.spec?.bindAddress or "0.0.0.0"
proxyPort = option("params")?.oxr?.spec?.proxyPort or 8443
nodePort = option("params")?.oxr?.spec?.nodePort or 32443
extraSANs = option("params")?.oxr?.spec?.extraSANs or ["localhost"]
serverUrl = option("params")?.oxr?.spec?.serverUrl or "https://localhost:32443"

# Additional values
customValues = option("params")?.oxr?.spec?.values or {}

# Observe configuration for secret access
enableObserve = option("params")?.oxr?.spec?.observeSecret?.enabled or False
observeClusterName = option("params")?.oxr?.spec?.observeSecret?.clusterName or clusterName
observeSecretName = option("params")?.oxr?.spec?.observeSecret?.secretName or "vc-{}-kubeconfig".format(name)
observeSecretNamespace = option("params")?.oxr?.spec?.observeSecret?.secretNamespace or targetNamespace

release = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = name
    }
    spec = {
        providerConfigRef: {
            name = clusterName
        }
        forProvider: {
            chart: {
                name = chartName
                repository = repository
                version = version
            }
            namespace = targetNamespace
            values: {
                controlPlane = {
                    statefulSet = {
                        persistence = {
                            volumeClaim = {
                                storageClass = storageClass
                            }
                        }
                    }
                    distro = {
                        k8s = {
                            enabled = True
                        }
                    }
                    proxy = {
                        bindAddress = bindAddress
                        port = proxyPort
                        extraSANs = extraSANs
                    }
                    service = {
                        enabled = True
                        spec = {
                            type = "NodePort"
                            ports = [
                                {
                                    name = "https"
                                    port = 443
                                    targetPort = proxyPort
                                    nodePort = nodePort
                                    protocol = "TCP"
                                }
                            ]
                        }
                    }
                }
                exportKubeConfig = {
                    server = serverUrl
                }
            } | customValues
        }
    }
}

# Create observe object for VCluster kubeconfig secret if enabled
observe_object = obj.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-secret-observer".format(name)
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = observeSecretName
                    namespace = observeSecretNamespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = observeClusterName
        }
    }
} if enableObserve else {}

# Build items list conditionally
items = [release] + ([observe_object] if enableObserve else [])
