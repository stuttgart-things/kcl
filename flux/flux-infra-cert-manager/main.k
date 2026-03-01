"""
Flux Infra Cert Manager Kustomization

Renders a Flux Kustomization for deploying cert-manager.

Usage:
    kcl run . -D cert_manager_version=v1.18.2
    kcl run oci://ghcr.io/stuttgart-things/flux-infra-cert-manager --tag 0.1.0
"""
import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}

_name: str = option("name") or _params?.name or "cert-manager"
_namespace: str = option("namespace") or _params?.namespace or "flux-system"
_interval: str = option("interval") or _params?.interval or "1h"
_retryInterval: str = option("retryInterval") or _params?.retryInterval or "1m"
_timeout: str = option("timeout") or _params?.timeout or "5m"
_sourceRefName: str = option("sourceRefName") or _params?.sourceRefName or "flux-infra"
_sourceRefKind: str = option("sourceRefKind") or _params?.sourceRefKind or "GitRepository"
_path: str = option("path") or _params?.path or "./infra/cert-manager/components/install"

# Cert Manager Configuration
_cert_manager_namespace: str = option("cert_manager_namespace") or _params?.cert_manager_namespace or "cert-manager"
_cert_manager_version: str = option("cert_manager_version") or _params?.cert_manager_version or "v1.18.2"

flux.Kustomization {
    metadata = {
        name = _name
        namespace = _namespace
    }
    spec = {
        interval = _interval
        retryInterval = _retryInterval
        timeout = _timeout
        sourceRef = {
            kind = _sourceRefKind
            name = _sourceRefName
        }
        path = _path
        prune = True
        wait = True
        postBuild.substitute = {
            CERT_MANAGER_NAMESPACE = _cert_manager_namespace
            CERT_MANAGER_VERSION = _cert_manager_version
        }
    }
}
