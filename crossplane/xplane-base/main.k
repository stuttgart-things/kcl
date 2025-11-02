import crossplane_provider_kubernetes.v1alpha1.kubernetes_crossplane_io_v1alpha1_provider_config as kube_pc

# --- Get XR spec fields ---
name = option("params")?.oxr?.spec?.name or "test"
enableHelmProvider = option("params")?.oxr?.spec?.enableHelmProvider?.enabled if option("params")?.oxr?.spec?.enableHelmProvider else True
enableKubernetesProvider = option("params")?.oxr?.spec?.enableKubernetesProvider?.enabled if option("params")?.oxr?.spec?.enableKubernetesProvider else True
connectionSecretNamespace = option("params")?.oxr?.spec?.connectionSecret?.namespace or "crossplane-system"
connectionSecretName = option("params")?.oxr?.spec?.connectionSecret?.name or "cluster-connection"
kubernetesProviderSecretKey = option("params")?.oxr?.spec?.enableKubernetesProvider?.secretKey or "kubeconfig"
helmProviderSecretKey = option("params")?.oxr?.spec?.enableHelmProvider?.secretKey or "kubeconfig"

# Kubernetes ProviderConfig
kube_provider_config = kube_pc.ProviderConfig {
    apiVersion = "kubernetes.crossplane.io/v1alpha1"
    kind = "ProviderConfig"
    metadata = {
        name = name
        annotations = {
            "krm.kcl.dev/composition-resource-name": "kubernetes-providerconfig"
        }
    }
    spec = {
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = connectionSecretNamespace
                name = connectionSecretName
                key = kubernetesProviderSecretKey
            }
        }
    }
} if enableKubernetesProvider else {}

# Helm ProviderConfig
helm_provider_config = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "ProviderConfig"
    metadata = {
        name = name
        annotations = {
            "krm.kcl.dev/composition-resource-name": "helm-providerconfig"
        }
    }
    spec = {
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = connectionSecretNamespace
                name = connectionSecretName
                key = helmProviderSecretKey
            }
        }
    }
} if enableHelmProvider else {}


provider_items = ([kube_provider_config] if enableKubernetesProvider else []) + ([helm_provider_config] if enableHelmProvider else [])

items = provider_items
