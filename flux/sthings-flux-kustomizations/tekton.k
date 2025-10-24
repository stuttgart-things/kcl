"""
Tekton Kustomization
Usage: kcl run base.k tekton.k
"""
import .base

# Tekton Configuration
tekton_namespace: str = option("tekton_namespace") or "tekton-pipelines"
tekton_version: str = option("tekton_version") or "0.76.1"
tekton_path: str = option("tekton_path") or "./cicd/tekton"

# Tekton Kustomization
kubernetes = [{
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind = "Kustomization"
    metadata = {
        name = "tekton"
        namespace = base.flux_namespace
    }
    spec = {
        interval = base.default_interval
        retryInterval = base.default_retry_interval
        timeout = base.default_timeout
        sourceRef = {
            kind = "GitRepository"
            name = base.source_repo_name
        }
        path = tekton_path
        prune = True
        wait = True
        postBuild = {
            substitute = {
                TEKTON_NAMESPACE = tekton_namespace
                TEKTON_VERSION = tekton_version
            }
        }
    }
}]