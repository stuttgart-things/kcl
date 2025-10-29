"""
Crossplane Kustomization
Usage: kcl run base.k crossplane.k
"""
import base
import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux
import "../../models/flux-source/v1/source_toolkit_fluxcd_io_v1_o_c_i_repository.k"

# Crossplane Configuration
crossplane_namespace: str = option("crossplane_namespace") or "crossplane-system"
crossplane_version: str = option("crossplane_version") or "1.20.0"
crossplane_path: str = option("crossplane_path") or "./apps/crossplane"
crossplane_helm_provider_version: str = option("crossplane_helm_provider_version") or "v0.21.0"
crossplane_k8s_provider_version: str = option("crossplane_k8s_provider_version") or "v0.18.0"
crossplane_terraform_provider_version: str = option("crossplane_terraform_provider_version") or "v0.21.0"
crossplane_terraform_provider_image: str = option("crossplane_terraform_provider_image") or "ghcr.io/stuttgart-things/sthings-cptf:1.12.0"

# Crossplane Kustomization using Flux schema
kubernetes = [flux.Kustomization {
    metadata.name = "crossplane"
    metadata.namespace = base.flux_namespace
    spec.interval = base.default_interval
    spec.retryInterval = base.default_retry_interval
    spec.timeout = base.default_timeout
    spec.sourceRef = {
        kind = base.source_repo_kind
        name = base.source_repo_name
    }
    spec.path = crossplane_path
    spec.prune = True
    spec.wait = True
    spec.postBuild.substitute = {
        CROSSPLANE_VERSION = crossplane_version
        CROSSPLANE_NAMESPACE = crossplane_namespace
        CROSSPLANE_HELM_PROVIDER_VERSION = crossplane_helm_provider_version
        CROSSPLANE_K8S_PROVIDER_VERSION = crossplane_k8s_provider_version
        CROSSPLANE_TERRAFORM_PROVIDER_VERSION = crossplane_terraform_provider_version
        CROSSPLANE_TERRAFORM_PROVIDER_IMAGE = crossplane_terraform_provider_image
    }
}]
oci_repository: OCIRepository = {
    metadata: {
        name: "my-app"
        namespace: "flux-system"
    }
    spec: {
        interval: "5m"
        url: "oci://ghcr.io/your-org/your-repo"
        ref: {
            tag: "1.0.0"
        }
    }
}
