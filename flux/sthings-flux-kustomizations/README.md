# flux-kustomization

## RENDER

```bash
kcl --quiet main.k \
-D enable_tekton=true \
-D enable_crossplane=true \
-D crossplane_namespace='"1.23"' \
--format yaml | grep -v "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```

## ADD as dep

```bash
kcl add oci://ghcr.io/stuttgart-things/flux-kustomization
```

## Example usage of Flux Kustomization resources in KCL


```python
"""
Example usage of Flux Kustomization resources in KCL
"""

import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

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
```


```python
""" Flux Applications Module Reusable Kustomization definitions that can be enabled/disabled and configured at runtime. Usage: kcl flux_apps.k -D enable_tekton=true -D enable_crossplane=true kcl flux_apps.k -D enable_tekton=true -D tekton_version="0.77.0" """
# ============================================================================
# Configuration Options (can be overridden at runtime with -D flag)
# ============================================================================
# Enable/Disable Applications (use -D enable_tekton=true)
_enable_tekton: bool = option("enable_tekton") or False
_enable_crossplane: bool = option("enable_crossplane") or False

# Common Configuration
_flux_namespace: str = option("flux_namespace") or "flux-system"
_source_repo_name: str = option("source_repo_name") or "flux-apps"
_default_interval: str = option("default_interval") or "1h"
_default_retry_interval: str = option("default_retry_interval") or "1m"
_default_timeout: str = option("default_timeout") or "5m"

# Tekton Configuration
_tekton_namespace: str = option("tekton_namespace") or "tekton-pipelines"
_tekton_version: str = option("tekton_version") or "0.76.1"
_tekton_path: str = option("tekton_path") or "./cicd/tekton"

# Crossplane Configuration
_crossplane_namespace: str = option("crossplane_namespace") or "crossplane-system"
_crossplane_version: str = option("crossplane_version") or "1.20.0"
_crossplane_path: str = option("crossplane_path") or "./apps/crossplane"
_crossplane_helm_provider_version: str = option("crossplane_helm_provider_version") or "v0.21.0"
_crossplane_k8s_provider_version: str = option("crossplane_k8s_provider_version") or "v0.18.0"
_crossplane_terraform_provider_version: str = option("crossplane_terraform_provider_version") or "v0.21.0"
_crossplane_terraform_provider_image: str = option("crossplane_terraform_provider_image") or "ghcr.io/stuttgart-things/sthings-cptf:1.12.0"

# ============================================================================
# Application Definitions
# ============================================================================
_tekton_kustomization = {
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind = "Kustomization"
    metadata = {
        name = "tekton"
        namespace = _flux_namespace
    }
    spec = {
        interval = _default_interval
        retryInterval = _default_retry_interval
        timeout = _default_timeout
        sourceRef = {
            kind = "GitRepository"
            name = _source_repo_name
        }
        path = _tekton_path
        prune = True
        wait = True
        postBuild = {
            substitute = {
                TEKTON_NAMESPACE = _tekton_namespace
                TEKTON_VERSION = _tekton_version
            }
        }
    }
}

_crossplane_kustomization = {
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind = "Kustomization"
    metadata = {
        name = "crossplane"
        namespace = _flux_namespace
    }
    spec = {
        interval = _default_interval
        retryInterval = _default_retry_interval
        timeout = _default_timeout
        sourceRef = {
            kind = "GitRepository"
            name = _source_repo_name
        }
        path = _crossplane_path
        prune = True
        wait = True
        postBuild = {
            substitute = {
                CROSSPLANE_VERSION = _crossplane_version
                CROSSPLANE_NAMESPACE = _crossplane_namespace
                CROSSPLANE_HELM_PROVIDER_VERSION = _crossplane_helm_provider_version
                CROSSPLANE_K8S_PROVIDER_VERSION = _crossplane_k8s_provider_version
                CROSSPLANE_TERRAFORM_PROVIDER_VERSION = _crossplane_terraform_provider_version
                CROSSPLANE_TERRAFORM_PROVIDER_IMAGE = _crossplane_terraform_provider_image
            }
        }
    }
}

# ============================================================================
# Output - Only export enabled kustomizations as separate YAML documents
# ============================================================================
# Use the special 'kubernetes' list to output each item as separate YAML document
kubernetes = [
    if _enable_tekton: _tekton_kustomization,
    if _enable_crossplane: _crossplane_kustomization,
]
```
