"""
Flux Infra Cilium LB Kustomization

Renders a Flux Kustomization for deploying Cilium LoadBalancer IP pool.

Usage:
    kcl run . -D cilium_lb_ip_start=10.31.103.12 -D cilium_lb_ip_stop=10.31.103.13
    kcl run oci://ghcr.io/stuttgart-things/flux-infra-cilium-lb --tag 0.1.0
"""
import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}

_name: str = option("name") or _params?.name or "cilium-lb"
_namespace: str = option("namespace") or _params?.namespace or "flux-system"
_interval: str = option("interval") or _params?.interval or "1h"
_retryInterval: str = option("retryInterval") or _params?.retryInterval or "1m"
_timeout: str = option("timeout") or _params?.timeout or "5m"
_sourceRefName: str = option("sourceRefName") or _params?.sourceRefName or "flux-infra"
_sourceRefKind: str = option("sourceRefKind") or _params?.sourceRefKind or "GitRepository"
_path: str = option("path") or _params?.path or "./infra/cilium/components/lb"

# Cilium LB Configuration
_cilium_lb_ip_start: str = option("cilium_lb_ip_start") or _params?.cilium_lb_ip_start or "10.31.103.12"
_cilium_lb_ip_stop: str = option("cilium_lb_ip_stop") or _params?.cilium_lb_ip_stop or "10.31.103.13"

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
            CILIUM_LB_IP_START = _cilium_lb_ip_start
            CILIUM_LB_IP_STOP = _cilium_lb_ip_stop
        }
    }
}
