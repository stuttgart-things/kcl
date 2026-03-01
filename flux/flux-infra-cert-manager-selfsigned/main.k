"""
Flux Infra Cert Manager Self-Signed Kustomization

Renders a Flux Kustomization for deploying cert-manager self-signed certificates.
Depends on cert-manager being deployed first.

Usage:
    kcl run . -D cert_manager_selfsigned_domain=k3s-infra.sthings-vsphere.labul.sva.de
    kcl run oci://ghcr.io/stuttgart-things/flux-infra-cert-manager-selfsigned --tag 0.1.0
"""
import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}

_name: str = option("name") or _params?.name or "cert-manager-selfsigned"
_namespace: str = option("namespace") or _params?.namespace or "flux-system"
_interval: str = option("interval") or _params?.interval or "1h"
_retryInterval: str = option("retryInterval") or _params?.retryInterval or "1m"
_timeout: str = option("timeout") or _params?.timeout or "5m"
_sourceRefName: str = option("sourceRefName") or _params?.sourceRefName or "flux-infra"
_sourceRefKind: str = option("sourceRefKind") or _params?.sourceRefKind or "GitRepository"
_path: str = option("path") or _params?.path or "./infra/cert-manager/components/selfsigned"

# Cert Manager Self-Signed Configuration
_cert_manager_namespace: str = option("cert_manager_namespace") or _params?.cert_manager_namespace or "cert-manager"
_cert_manager_selfsigned_domain: str = option("cert_manager_selfsigned_domain") or _params?.cert_manager_selfsigned_domain or "k3s-infra.sthings-vsphere.labul.sva.de"
_cert_manager_selfsigned_secret_name: str = option("cert_manager_selfsigned_secret_name") or _params?.cert_manager_selfsigned_secret_name or "wildcard-k3s-infra-tls"
_cert_manager_selfsigned_cert_name: str = option("cert_manager_selfsigned_cert_name") or _params?.cert_manager_selfsigned_cert_name or "wildcard-k3s-infra-tls"
_cert_manager_selfsigned_cert_namespace: str = option("cert_manager_selfsigned_cert_namespace") or _params?.cert_manager_selfsigned_cert_namespace or "default"
_cert_manager_selfsigned_issuer: str = option("cert_manager_selfsigned_issuer") or _params?.cert_manager_selfsigned_issuer or "vault-pki"

# DependsOn
_dependsOnName: str = option("dependsOnName") or _params?.dependsOnName or "cert-manager"

flux.Kustomization {
    metadata = {
        name = _name
        namespace = _namespace
    }
    spec = {
        interval = _interval
        retryInterval = _retryInterval
        timeout = _timeout
        dependsOn = [{name = _dependsOnName}]
        sourceRef = {
            kind = _sourceRefKind
            name = _sourceRefName
        }
        path = _path
        prune = True
        wait = True
        postBuild.substitute = {
            CERT_MANAGER_NAMESPACE = _cert_manager_namespace
            CERT_MANAGER_SELFSIGNED_DOMAIN = _cert_manager_selfsigned_domain
            CERT_MANAGER_SELFSIGNED_SECRET_NAME = _cert_manager_selfsigned_secret_name
            CERT_MANAGER_SELFSIGNED_CERT_NAME = _cert_manager_selfsigned_cert_name
            CERT_MANAGER_SELFSIGNED_CERT_NAMESPACE = _cert_manager_selfsigned_cert_namespace
            CERT_MANAGER_SELFSIGNED_ISSUER = _cert_manager_selfsigned_issuer
        }
    }
}
