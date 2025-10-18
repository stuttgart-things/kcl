import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as obj
import crossplane_provider_kubernetes.v1alpha1.kubernetes_crossplane_io_v1alpha1_provider_config as kube_pc
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_provider_config as helm_pc

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

# Additional secrets configuration for better Crossplane integration
additionalSecrets = option("params")?.oxr?.spec?.additionalSecrets or []

# Connection secret configuration
enableConnectionSecret = option("params")?.oxr?.spec?.connectionSecret?.enabled or True
connectionSecretName = option("params")?.oxr?.spec?.connectionSecret?.name or "{}-connection".format(name)
connectionSecretNamespace = option("params")?.oxr?.spec?.connectionSecret?.namespace or "crossplane-system"
vclusterSecretName = option("params")?.oxr?.spec?.connectionSecret?.vclusterSecretName or "vc-{}".format(name)
vclusterSecretNamespace = option("params")?.oxr?.spec?.connectionSecret?.vclusterSecretNamespace or targetNamespace

# VCluster Helm Release
release = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = name
    }
    spec = {
        deletionPolicy = "Delete"
        providerConfigRef: {
            name = clusterName
        }
        managementPolicies = ["*"]
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
                } | ({
                    additionalSecrets = additionalSecrets
                } if additionalSecrets else {})
            } | customValues
        }
    }
}

# Kubernetes Object to create connection secret from VCluster kubeconfig
kubeconfig_reader = obj.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "vcluster-kubeconfig-reader"
    }
    spec = {
        deletionPolicy = "Delete"
        managementPolicies = ["Observe"]  # Important: Only observe, don't manage!
        providerConfigRef = {
            name = clusterName
        }
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = vclusterSecretName
                    namespace = vclusterSecretNamespace
                }
            }
        }
        connectionDetails = [
            {
                apiVersion = "v1"
                kind = "Secret"
                name = vclusterSecretName
                namespace = vclusterSecretNamespace
                fieldPath = "data.config"
                toConnectionSecretKey = "kubeconfig"
            }
            {
                apiVersion = "v1"
                kind = "Secret"
                name = vclusterSecretName
                namespace = vclusterSecretNamespace
                fieldPath = "data.certificate-authority"
                toConnectionSecretKey = "ca.crt"
            }
        ]
        writeConnectionSecretToRef = {
            name = connectionSecretName  # This is what gets created
            namespace = connectionSecretNamespace
        }
    }
} if enableConnectionSecret else {}

# Kubernetes ProviderConfig for VCluster
vcluster_kube_provider_config = kube_pc.ProviderConfig {
    apiVersion = "kubernetes.crossplane.io/v1alpha1"
    kind = "ProviderConfig"
    metadata = {
        name = name
    }
    spec = {
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = connectionSecretNamespace
                name = connectionSecretName  # Fixed: matches the Object's output
                key = "kubeconfig"
            }
        }
    }
} if enableConnectionSecret else {}

# Helm ProviderConfig for VCluster
vcluster_helm_provider_config = helm_pc.ProviderConfig {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "ProviderConfig"
    metadata = {
        name = "{}-helm".format(name)
    }
    spec = {
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = connectionSecretNamespace
                name = connectionSecretName
                key = "kubeconfig"
            }
        }
    }
} if enableConnectionSecret else {}

# Build items list
base_items = [release]
connection_items = ([kubeconfig_reader, vcluster_kube_provider_config, vcluster_helm_provider_config] 
                   if enableConnectionSecret else [])
items = base_items + connection_items