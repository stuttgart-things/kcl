# Read parameters (Composition format)
_params = option("params") or {}
_spec = _params?.oxr?.spec or {}

# Extract fields with fallbacks
_deploymentName = _spec?.deploymentName or option("deploymentName") or "hello-app"
_namespace = _spec?.namespace or option("namespace") or "default"
_image = _spec?.image or option("image") or "nginx:latest"
_replicas = _spec?.replicas or option("replicas") or 1
_port = _spec?.port or option("port") or 80
_providerConfig = _spec?.providerConfig or option("providerConfig") or "kubernetes-provider"

# Generate the Kubernetes Deployment
_deployment = {
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = {
        name = _deploymentName
        namespace = _namespace
        labels = {
            app = _deploymentName
            "managed-by" = "kcl"
        }
    }
    spec = {
        replicas = _replicas
        selector = {
            matchLabels = {
                app = _deploymentName
            }
        }
        template = {
            metadata = {
                labels = {
                    app = _deploymentName
                }
            }
            spec = {
                containers = [
                    {
                        name = _deploymentName
                        image = _image
                        ports = [
                            {
                                containerPort = _port
                            }
                        ]
                        resources = {
                            requests = {
                                cpu = "100m"
                                memory = "128Mi"
                            }
                            limits = {
                                cpu = "500m"
                                memory = "512Mi"
                            }
                        }
                    }
                ]
            }
        }
    }
}

# Wrap in Crossplane Object for Kubernetes provider
_crossplaneObject = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {
        name = _deploymentName
        namespace = "default"
    }
    spec = {
        forProvider = {
            manifest = _deployment
        }
        providerConfigRef = {
            name = _providerConfig
        }
    }
}

# Output based on mode
if _params != {}:
    # Composition mode: return items array for Crossplane
    items = [_crossplaneObject]
else:
    # Direct mode: return single Crossplane Object resource
    _crossplaneObject
