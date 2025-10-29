"""
Tekton Kustomization
Usage: kcl run base.k tekton.k
"""
import base
import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Tekton Configuration
tekton_namespace: str = option("tekton_namespace") or "tekton-pipelines"
tekton_version: str = option("tekton_version") or "0.76.1"
tekton_path: str = option("tekton_path") or "./cicd/tekton"

# Tekton Kustomization using Flux schema
kubernetes = [flux.Kustomization {
    metadata.name = "tekton"
    metadata.namespace = base.flux_namespace
    spec.interval = base.default_interval
    spec.retryInterval = base.default_retry_interval
    spec.timeout = base.default_timeout
    spec.sourceRef = {
        kind = base.source_repo_kind
        name = base.source_repo_name
    }
    spec.path = tekton_path
    spec.prune = True
    spec.wait = True
    spec.postBuild.substitute = {
        TEKTON_NAMESPACE = tekton_namespace
        TEKTON_VERSION = tekton_version
    }
}]
