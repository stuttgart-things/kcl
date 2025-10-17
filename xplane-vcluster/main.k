import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm

# --- Get XR spec fields ---
name = option("params")?.oxr?.spec?.name or "test"
version = option("params")?.oxr?.spec?.version or "1.2.3"
chartName = option("params")?.oxr?.spec?.chartName or "test"
repository = option("params")?.oxr?.spec?.repository or "https://helm.test.io"
clusterName = option("params")?.oxr?.spec?.clusterName or "kind"
targetNamespace = option("params")?.oxr?.spec?.targetNamespace or "default"

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
