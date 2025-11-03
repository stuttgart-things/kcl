# --- Get XR spec fields ---
_params = option("params")
name = _params?.oxr?.spec?.name or "test"
version = _params?.oxr?.spec?.version or "0.29.0"
chartName = _params?.oxr?.spec?.chartName or "vcluster"
repository = _params?.oxr?.spec?.repository or "https://charts.loft.sh"
clusterName = _params?.oxr?.spec?.clusterName or "kind"
targetNamespace = _params?.oxr?.spec?.targetNamespace or "vcluster"

# VCluster specific configuration
storageClass = _params?.oxr?.spec?.storageClass or "standard"
bindAddress = _params?.oxr?.spec?.bindAddress or "0.0.0.0"
proxyPort = _params?.oxr?.spec?.proxyPort or 8443
nodePort = _params?.oxr?.spec?.nodePort or 32443
extraSANs = _params?.oxr?.spec?.extraSANs or ["localhost"]
serverUrl = _params?.oxr?.spec?.serverUrl or "https://localhost:32443"

# Additional values
customValues = _params?.oxr?.spec?.values or {}

# Additional secrets configuration for better Crossplane integration
additionalSecrets = _params?.oxr?.spec?.additionalSecrets or []

# Connection secret configuration
connectionSecretConfig = _params?.oxr?.spec?.connectionSecret or {}
enableConnectionSecret = True if connectionSecretConfig == {} else (connectionSecretConfig?.enabled or True)
connectionSecretName = connectionSecretConfig?.name or "{}-connection".format(name)
connectionSecretNamespace = connectionSecretConfig?.namespace or "crossplane-system"
vclusterSecretName = connectionSecretConfig?.vclusterSecretName or "vc-{}".format(name)
vclusterSecretNamespace = connectionSecretConfig?.vclusterSecretNamespace or targetNamespace

# PushSecret configuration
pushSecretConfig = _params?.oxr?.spec?.pushSecret or {}
enablePushSecret = pushSecretConfig?.enabled or False
pushSecretName = pushSecretConfig?.name or "pushsecret-{}".format(name)
pushSecretNamespace = pushSecretConfig?.namespace or "default"
pushSecretClusterName = pushSecretConfig?.clusterName or clusterName  # Can be different from main clusterName
pushSecretStoreRef = pushSecretConfig?.secretStoreRef or "vault-backend-kubeconfigs"
pushSecretRefreshInterval = pushSecretConfig?.refreshInterval or "1m"

# VCluster Helm Release
release = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = name
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vcluster-release"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        providerConfigRef = {
            name = clusterName
        }
        managementPolicies = ["*"]
        forProvider = {
            chart = {
                name = chartName
                repository = repository
                version = version
            }
            namespace = targetNamespace
            values = {
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
                exportKubeConfig = ({
                    server = serverUrl
                } | ({
                    additionalSecrets = additionalSecrets
                } if additionalSecrets else {}))
            } | customValues
        }
    }
}

# Kubernetes Object to create connection secret from VCluster kubeconfig
kubeconfig_reader = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = name
        annotations = {
            "krm.kcl.dev/composition-resource-name" = name
        }
    }
    spec = {
        deletionPolicy = "Delete"
        managementPolicies = ["Observe"]
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
                toConnectionSecretKey = "kubeconfig" # pragma: allowlist secret
            }
            {
                apiVersion = "v1"
                kind = "Secret"
                name = vclusterSecretName
                namespace = vclusterSecretNamespace
                fieldPath = "data.certificate-authority"
                toConnectionSecretKey = "ca.crt" # pragma: allowlist secret
            }
        ]
        writeConnectionSecretToRef = {
            name = connectionSecretName
            namespace = connectionSecretNamespace
        }
    }
} if enableConnectionSecret else {}

# PushSecret for External Secrets Operator (wrapped in Kubernetes Object)
push_secret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-pushsecret".format(name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vcluster-pushsecret"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        providerConfigRef = {
            name = pushSecretClusterName  # Uses separate cluster config
        }
        forProvider = {
            manifest = {
                apiVersion = "external-secrets.io/v1alpha1"
                kind = "PushSecret"
                metadata = {
                    name = pushSecretName
                    namespace = pushSecretNamespace
                }
                spec = {
                    data = [
                        {
                            conversionStrategy = "None"
                            match = {
                                remoteRef = {
                                    property = "kubeconfig"
                                    remoteKey = connectionSecretName
                                }
                                secretKey = "kubeconfig" # pragma: allowlist secret
                            }
                        }
                    ]
                    deletionPolicy = "None"
                    refreshInterval = pushSecretRefreshInterval
                    secretStoreRefs = [
                        {
                            kind = "SecretStore"
                            name = pushSecretStoreRef
                        }
                    ]
                    selector = {
                        secret = {
                            name = connectionSecretName
                        }
                    }
                    updatePolicy = "Replace"
                }
            }
        }
    }
} if enablePushSecret and enableConnectionSecret else {}

# Kubernetes ProviderConfig for VCluster
vcluster_kube_provider_config = {
    apiVersion = "kubernetes.crossplane.io/v1alpha1"
    kind = "ProviderConfig"
    metadata = {
        name = name
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vcluster-kubernetes-providerconfig"
        }
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

# Helm ProviderConfig for VCluster
vcluster_helm_provider_config = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "ProviderConfig"
    metadata = {
        name = "{}-helm".format(name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vcluster-helm-providerconfig"
        }
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
connection_items = [kubeconfig_reader, vcluster_kube_provider_config, vcluster_helm_provider_config] if enableConnectionSecret else []
push_secret_items = [push_secret] if enablePushSecret and enableConnectionSecret else []
items = base_items + connection_items + push_secret_items
