"""
Example usage of Flux Kustomization resources in KCL
"""

import ..v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Basic Kustomization example
basic_kustomization = flux.Kustomization {
    metadata = {
        name = "my-app"
        namespace = "flux-system"
    }
    spec = {
        interval = "5m"
        prune = True
        sourceRef = {
            kind = "GitRepository"
            name = "my-repo"
        }
        path = "./manifests"
    }
}

# Advanced Kustomization with health checks and post-build substitutions
advanced_kustomization = flux.Kustomization {
    metadata = {
        name = "infrastructure"
        namespace = "flux-system"
        labels = {
            environment = "production"
        }
    }
    spec = {
        interval = "10m"
        retryInterval = "2m"
        timeout = "5m"
        prune = True
        wait = True
        force = False

        sourceRef = {
            kind = "GitRepository"
            name = "infrastructure-repo"
            namespace = "flux-system"
        }

        path = "./clusters/production"
        targetNamespace = "default"

        # Add common labels and annotations to all resources
        commonMetadata = {
            labels = {
                "app.kubernetes.io/managed-by" = "flux"
                "environment" = "production"
            }
            annotations = {
                "owner" = "platform-team"
            }
        }

        # Dependencies on other Kustomizations
        dependsOn = [
            {
                name = "cert-manager"
                namespace = "flux-system"
            }
            {
                name = "ingress-nginx"
            }
        ]

        # Health checks for specific resources
        healthChecks = [
            {
                kind = "Deployment"
                name = "my-app"
                namespace = "default"
                apiVersion = "apps/v1"
            }
            {
                kind = "Service"
                name = "my-service"
            }
        ]

        # Variable substitution
        postBuild = {
            substitute = {
                CLUSTER_NAME = "prod-cluster"
                DOMAIN = "example.com"
                REPLICAS = "3"
            }
            substituteFrom = [
                {
                    kind = "ConfigMap"
                    name = "cluster-vars"
                }
                {
                    kind = "Secret"
                    name = "cluster-secrets"
                    optional = True
                }
            ]
        }

        # Patches for specific resources
        patches = [
            {
                patch = """
                apiVersion: apps/v1
                kind: Deployment
                metadata:
                  name: my-app
                spec:
                  replicas: 3
                """
                target = {
                    kind = "Deployment"
                    name = "my-app"
                    labelSelector = "app=my-app"
                }
            }
        ]

        # Image overrides
        images = [
            {
                name = "nginx"
                newName = "my-registry.io/nginx"
                newTag = "1.21.0"
            }
            {
                name = "redis"
                newName = "my-registry.io/redis"
                digest = "sha256:abc123..."
            }
        ]
    }
}

# Kustomization with SOPS decryption
encrypted_kustomization = flux.Kustomization {
    metadata = {
        name = "secrets"
        namespace = "flux-system"
    }
    spec = {
        interval = "5m"
        prune = True

        sourceRef = {
            kind = "GitRepository"
            name = "secrets-repo"
        }

        path = "./secrets"

        # Enable SOPS decryption
        decryption = {
            provider = "sops"
            secretRef = {
                name = "sops-gpg"
            }
        }
    }
}

# Kustomization for multi-cluster deployment
remote_cluster_kustomization = flux.Kustomization {
    metadata = {
        name = "remote-app"
        namespace = "flux-system"
    }
    spec = {
        interval = "10m"
        prune = True

        sourceRef = {
            kind = "GitRepository"
            name = "app-repo"
        }

        # Deploy to remote cluster
        kubeConfig = {
            secretRef = {
                name = "remote-cluster-kubeconfig"
                key = "value"
            }
        }

        serviceAccountName = "flux-reconciler"
    }
}

# Kustomization with name prefix/suffix
namespaced_kustomization = flux.Kustomization {
    metadata = {
        name = "staging-app"
        namespace = "flux-system"
    }
    spec = {
        interval = "5m"
        prune = True

        sourceRef = {
            kind = "GitRepository"
            name = "app-repo"
        }

        path = "./app"
        targetNamespace = "staging"

        # Add prefix/suffix to resource names
        namePrefix = "staging-"
        nameSuffix = "-v2"
    }
}

# Kustomization with custom health check expressions (CEL)
cel_health_kustomization = flux.Kustomization {
    metadata = {
        name = "custom-health"
        namespace = "flux-system"
    }
    spec = {
        interval = "5m"
        prune = True
        wait = True

        sourceRef = {
            kind = "GitRepository"
            name = "app-repo"
        }

        # Custom health checks using CEL expressions
        healthCheckExprs = [
            {
                apiVersion = "v1"
                kind = "MyCustomResource"
                current = "object.status.phase == 'Ready'"
                failed = "object.status.phase == 'Failed'"
                inProgress = "object.status.phase == 'Progressing'"
            }
        ]
    }
}

# Export all kustomizations as a list
kustomizations = [
    basic_kustomization,
    advanced_kustomization,
    encrypted_kustomization,
    remote_cluster_kustomization,
    namespaced_kustomization,
    cel_health_kustomization,
]
