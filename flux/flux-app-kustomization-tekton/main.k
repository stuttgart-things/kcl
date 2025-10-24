import flux_helmrelease.v2.helm_toolkit_fluxcd_io_v2_helm_release as helm

schema TektonConfig:
    name: str = "tekton-pipelines"
    namespace: str = "tekton-pipelines"
    version: str = "0.76.1"
    tenant: str = "sthings-team"
    chartRepo: str = "oci://ghcr.io/stuttgart-things/tekton"


# Namespace resource (as generic K8s object)
makeNamespace = lambda cfg: TektonConfig -> any {
    {
        apiVersion = "v1"
        kind = "Namespace"
        metadata = {
            name = cfg.namespace
            labels = {
                "toolkit.fluxcd.io/tenant" = cfg.tenant
            }
        }
    }
}

# HelmRepository resource (as generic K8s object)
makeHelmRepo = lambda cfg: TektonConfig -> any {
    {
        apiVersion = "source.toolkit.fluxcd.io/v1beta2"
        kind = "HelmRepository"
        metadata = {
            name = "stuttgart-things"
            namespace = cfg.namespace
        }
        spec = {
            type = "oci"
            interval = "1h"
            url = cfg.chartRepo
        }
    }
}

# HelmRelease resource
makeHelmRelease = lambda cfg: TektonConfig -> helm.HelmRelease {
    helm.HelmRelease {
        metadata = {
            name = cfg.name
            namespace = cfg.namespace
        }
        spec = {
            interval = "30m"
            chart = {
                spec = {
                    chart = "tekton"
                    version = cfg.version
                    sourceRef = {
                        kind = "HelmRepository"
                        name = "stuttgart-things"
                        namespace = cfg.namespace
                    }
                }
            }
        }
    }
}

# Generate all resources
tektonResources = lambda cfg: TektonConfig -> [any] {
    [
        makeNamespace(cfg),
        makeHelmRepo(cfg),
        makeHelmRelease(cfg)
    ]
}
