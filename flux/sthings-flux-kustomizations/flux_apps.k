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