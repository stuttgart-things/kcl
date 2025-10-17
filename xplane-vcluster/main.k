import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm

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
            values: {}
        }
    }
}

items = [release]
