"""
Simple Flux Kustomization Example

This example demonstrates creating a basic Flux Kustomization
using the simplified helper functions.
"""

import ..main as flux

# Example 1: Simple GitRepository-based Kustomization
simpleApp = flux.gitKustomization(
    "my-application",
    "my-git-repo",
    "./deploy/production"
)

# Example 2: Full configuration with all options
advancedApp = flux.generateKustomization(flux.SimpleKustomization {
    name = "advanced-app"
    namespace = "flux-system"
    path = "./apps/staging"
    sourceRef = flux.SourceRef {
        kind = "GitRepository"
        name = "platform-repo"
        namespace = "flux-system"
    }
    interval = "10m"
    prune = True
    targetNamespace = "staging"
    wait = True
    timeout = "10m"
    force = False
    dependsOn = [
        flux.DependencyRef {
            name = "infrastructure"
        }
    ]
    healthChecks = [
        flux.HealthCheck {
            apiVersion = "apps/v1"
            kind = "Deployment"
            namespace = "staging"
        }
    ]
    postBuild = flux.PostBuild {
        substitute = {
            ENVIRONMENT = "staging"
            REGION = "eu-west-1"
        }
        substituteFrom = [
            flux.SubstituteReference {
                kind = "ConfigMap"
                name = "cluster-config"
            }
        ]
    }
    labels = {
        "app.kubernetes.io/managed-by" = "flux"
        "environment" = "staging"
    }
    annotations = {
        "description" = "Staging environment application"
    }
})

# Example 3: OCI Repository-based Kustomization
ociApp = flux.ociKustomization(
    "oci-application",
    "my-oci-repo",
    "./manifests"
)

# Example 4: Multi-environment with dependencies
infrastructure = flux.gitKustomization(
    "infrastructure",
    "platform-repo",
    "./infrastructure"
)

applications = flux.generateKustomization(flux.SimpleKustomization {
    name = "applications"
    sourceRef = flux.SourceRef {
        kind = "GitRepository"
        name = "platform-repo"
    }
    path = "./applications"
    dependsOn = [
        flux.DependencyRef {
            name = "infrastructure"
        }
    ]
    prune = True
    wait = True
})

# Export all examples
items = simpleApp + advancedApp + ociApp + infrastructure + applications
