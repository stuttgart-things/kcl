import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as obj

# Get the XR spec fields
name = option("params")?.oxr?.spec.name or ""
targetNamespace = option("params")?.oxr?.spec.targetNamespace or ""
templateRef = option("params")?.oxr?.spec.templateRef or ""
hardwareRef = option("params")?.oxr?.spec.hardwareRef or ""
macAddr = option("params")?.oxr?.spec.macAddr or ""

cluster = option("params")?.oxr?.spec.cluster or ""

# Helm Release parameters
helmRelease = option("params")?.oxr?.spec.helmRelease or {}
enableHelmRelease = option("params")?.oxr?.spec.enableHelmRelease or False

# Boolean flag to control output - check explicitly for False
_printItemsValue = option("params")?.oxr?.spec.printItems
printItems = False if _printItemsValue == False else True

workflow_object = obj.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = name
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "tinkerbell.org/v1alpha1"
                kind = "Workflow"
                metadata = {
                    name = name
                    namespace = targetNamespace
                }
                spec = {
                    templateRef = templateRef
                    hardwareRef = hardwareRef
                    hardwareMap = {
                        device_1 = macAddr
                    }
                }
            }
        }
        deletionPolicy = "Delete"
        managementPolicies = ["*"]
        providerConfigRef = {
            name = cluster
        }
    }
}

# Helm Release object - creates a Crossplane Object that wraps a Helm Release
helm_release_object = obj.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = name + "-helm-release"
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "helm.crossplane.io/v1beta1"
                kind = "Release"
                metadata = {
                    name = helmRelease.get("name", name + "-release")
                }
                spec = {
                    rollbackLimit = helmRelease.get("rollbackLimit", 3)
                    forProvider = {
                        chart = {
                            name = helmRelease.get("chart", {}).get("name", "wordpress")
                            repository = helmRelease.get("chart", {}).get("repository", "oci://localhost:5000/helm-charts")
                            version = helmRelease.get("chart", {}).get("version", "15.2.5")
                        }
                        namespace = helmRelease.get("namespace", "default")
                        insecureSkipTLSVerify = helmRelease.get("insecureSkipTLSVerify", True)
                        skipCRDs = helmRelease.get("skipCRDs", True)
                        values = helmRelease.get("values", {
                            "service": {
                                "type": "ClusterIP"
                            }
                        })
                        set = helmRelease.get("set", [
                            {
                                "name": "param1"
                                "value": "value1"
                            }
                        ])
                    }
                    providerConfigRef = {
                        name = helmRelease.get("providerConfig", "helm-provider")
                    }
                }
            }
        }
        deletionPolicy = "Delete"
        managementPolicies = ["*"] 
        providerConfigRef = {
            name = cluster
        }
    }
} if enableHelmRelease else None

items = [workflow_object] + ([helm_release_object] if helm_release_object and printItems else []) if printItems else []