import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm

# Get the XR spec fields
name = option("params")?.oxr?.spec.name or ""
targetNamespace = option("params")?.oxr?.spec.targetNamespace or "default"
chartName = option("params")?.oxr?.spec.chartName or "nginx"
chartRepo = option("params")?.oxr?.spec.chartRepo or "https://charts.bitnami.com/bitnami"
chartVersion = option("params")?.oxr?.spec.chartVersion or "15.0.0"
replicaCount = option("params")?.oxr?.spec.replicaCount or 1
serviceType = option("params")?.oxr?.spec.serviceType or "ClusterIP"

cluster = option("params")?.oxr?.spec.cluster or "default"

helm_release = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = name
    }
    spec = {
        providerConfigRef: { name = cluster }
        forProvider: {
            chart: {
                name = chartName
                repository = chartRepo
                version = chartVersion
            }
            namespace = targetNamespace
            values: {
                replicaCount = replicaCount
                service: {
                    type = serviceType
                }
            }
        }
    }
}

items = [helm_release]
