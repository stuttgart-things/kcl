import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as obj

# Get the XR spec fields
name = option("params")?.oxr?.spec.name or ""
targetNamespace = option("params")?.oxr?.spec.targetNamespace or ""
cluster = option("params")?.oxr?.spec.cluster or ""
data = option("params")?.oxr?.spec.data or {}

configmap_object = obj.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = name
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = name
                    namespace = targetNamespace
                }
                data = data
            }
        }
        deletionPolicy = "Delete"
        managementPolicies = ["*"]
        providerConfigRef = {
            name = cluster
        }
    }
}

items = [configmap_object]
