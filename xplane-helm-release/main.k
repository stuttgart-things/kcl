import crossplane_provider_helm.v1beta1.helm_crossplane_io_v1beta1_release as helm_release

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

# Create the Helm Release object using Crossplane Provider Helm
helm_release_object = helm_release.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = name
        labels = {
            "app" = name
            "managed-by" = "crossplane"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        forProvider = {
            chart = {
                name = chart
                repository = repository
                version = version
            }
            namespace = namespace
            values = helmValues
        }
        managementPolicies = ["*"]
        providerConfigRef = {
            name = cluster
        }
    }
}

# Output the items array based on printItems flag
items = [helm_release_object] if printItems else []