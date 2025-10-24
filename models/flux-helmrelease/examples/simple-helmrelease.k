"""
Simple Flux HelmRelease Examples
"""

import ..main as flux

# Example 1: Simple HelmRelease from HelmRepository
nginx = flux.helmReleaseFromRepo(
    "nginx",
    "nginx",
    "15.0.0",
    "bitnami",
    {
        replicaCount = 3
        service = {
            type = "LoadBalancer"
        }
    }
)

# Example 2: HelmRelease from GitRepository
myApp = flux.helmReleaseFromGit(
    "my-application",
    "./charts/app",
    "my-git-repo",
    {
        environment = "production"
        replicas = 5
    }
)

# Example 3: Full configuration with dependencies
monitoring = flux.generateHelmRelease(flux.SimpleHelmRelease {
    name = "prometheus"
    namespace = "flux-system"
    chart = flux.ChartRef {
        name = "kube-prometheus-stack"
        version = "55.0.0"
        sourceRef = flux.SourceRef {
            kind = "HelmRepository"
            name = "prometheus-community"
        }
    }
    interval = "10m"
    targetNamespace = "monitoring"
    releaseName = "prometheus"
    values = {
        prometheus = {
            prometheusSpec = {
                retention = "30d"
                storageSpec = {
                    volumeClaimTemplate = {
                        spec = {
                            resources = {
                                requests = {
                                    storage = "50Gi"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    install = flux.InstallConfig {
        createNamespace = True
        remediation = flux.RemediationConfig {
            retries = 3
        }
    }
    upgrade = flux.UpgradeConfig {
        cleanupOnFail = True
        remediation = flux.RemediationConfig {
            retries = 3
        }
    }
})

# Example 4: HelmRelease with dependencies
app = flux.generateHelmRelease(flux.SimpleHelmRelease {
    name = "my-app"
    chart = flux.ChartRef {
        name = "my-app"
        version = "1.0.0"
        sourceRef = flux.SourceRef {
            kind = "HelmRepository"
            name = "my-repo"
        }
    }
    targetNamespace = "production"
    dependsOn = [
        flux.DependencyRef {
            name = "prometheus"
            namespace = "flux-system"
        }
    ]
    values = {
        image = {
            tag = "v1.2.3"
        }
        resources = {
            limits = {
                cpu = "1000m"
                memory = "1Gi"
            }
        }
    }
})

# Export all examples
items = nginx + myApp + monitoring + app
