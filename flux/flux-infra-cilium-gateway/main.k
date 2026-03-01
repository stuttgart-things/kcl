"""
Flux Infra Cilium Gateway Kustomization

Renders a Flux Kustomization for deploying Cilium Gateway API.
Depends on cilium-lb and cert-manager-selfsigned.

Usage:
    kcl run . -D cilium_gateway_domain=k3s-infra.sthings-vsphere.labul.sva.de
    kcl run oci://ghcr.io/stuttgart-things/flux-infra-cilium-gateway --tag 0.1.0
"""
import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}

_name: str = option("name") or _params?.name or "cilium-gateway"
_namespace: str = option("namespace") or _params?.namespace or "flux-system"
_interval: str = option("interval") or _params?.interval or "1h"
_retryInterval: str = option("retryInterval") or _params?.retryInterval or "1m"
_timeout: str = option("timeout") or _params?.timeout or "5m"
_sourceRefName: str = option("sourceRefName") or _params?.sourceRefName or "flux-infra"
_sourceRefKind: str = option("sourceRefKind") or _params?.sourceRefKind or "GitRepository"
_path: str = option("path") or _params?.path or "./infra/cilium/components/gateway"

# Cilium Gateway Configuration
_cilium_gateway_name: str = option("cilium_gateway_name") or _params?.cilium_gateway_name or "k3s-infra-gateway"
_cilium_gateway_namespace: str = option("cilium_gateway_namespace") or _params?.cilium_gateway_namespace or "default"
_cilium_gateway_domain: str = option("cilium_gateway_domain") or _params?.cilium_gateway_domain or "k3s-infra.sthings-vsphere.labul.sva.de"
_cilium_gateway_tls_secret: str = option("cilium_gateway_tls_secret") or _params?.cilium_gateway_tls_secret or "wildcard-k3s-infra-tls"

# DependsOn
_dependsOnNamesStr: str = option("dependsOnNames") or _params?.dependsOnNames or "cilium-lb,cert-manager-selfsigned"
_dependsOnNames = [name.strip() for name in _dependsOnNamesStr.split(",") if name.strip()]

flux.Kustomization {
    metadata = {
        name = _name
        namespace = _namespace
    }
    spec = {
        interval = _interval
        retryInterval = _retryInterval
        timeout = _timeout
        dependsOn = [{name = depName} for depName in _dependsOnNames]
        sourceRef = {
            kind = _sourceRefKind
            name = _sourceRefName
        }
        path = _path
        prune = True
        wait = True
        postBuild.substitute = {
            CILIUM_GATEWAY_NAME = _cilium_gateway_name
            CILIUM_GATEWAY_NAMESPACE = _cilium_gateway_namespace
            CILIUM_GATEWAY_DOMAIN = _cilium_gateway_domain
            CILIUM_GATEWAY_TLS_SECRET = _cilium_gateway_tls_secret
        }
    }
}
