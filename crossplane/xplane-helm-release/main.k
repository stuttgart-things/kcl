import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as obj

# Get the XR spec fields for Helm Release
name = option("params")?.oxr?.spec.name or ""
namespace = option("params")?.oxr?.spec.namespace or "default"
chart = option("params")?.oxr?.spec.chart or ""
repository = option("params")?.oxr?.spec.repository or ""
version = option("params")?.oxr?.spec.version or ""
cluster = option("params")?.oxr?.spec.cluster or ""

# Helm values as a map
helmValues = option("params")?.oxr?.spec.values or {}

# Boolean flag to control output - check explicitly for False
_printItemsValue = option("params")?.oxr?.spec.printItems
printItems = False if _printItemsValue == False else True

# Create the Helm Release object using Crossplane Kubernetes Provider
helm_release_object = obj.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = name + "-helm-release"
        labels = {
            "app" = name
            "managed-by" = "crossplane"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        forProvider = {
            manifest = {
                apiVersion = "helm.cattle.io/v1"
                kind = "HelmChart"
                metadata = {
                    name = name
                    namespace = namespace
                }
                spec = {
                    chart = chart
                    repo = repository
                    version = version
                    targetNamespace = namespace
                    valuesContent = helmValues if helmValues else {}
                }
            }
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = cluster
        }
    }
}

# Output the items array based on printItems flag
items = [helm_release_object] if printItems else []
