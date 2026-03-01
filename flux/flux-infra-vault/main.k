"""
Flux Infra Vault Kustomization

Renders a Flux Kustomization for deploying HashiCorp Vault.
Depends on cilium-gateway.

Usage:
    kcl run . -D vault_domain=k3s-infra.sthings-vsphere.labul.sva.de
    kcl run oci://ghcr.io/stuttgart-things/flux-infra-vault --tag 0.1.0
"""
import flux_kustomization.v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}

_name: str = option("name") or _params?.name or "vault"
_namespace: str = option("namespace") or _params?.namespace or "flux-system"
_interval: str = option("interval") or _params?.interval or "1h"
_retryInterval: str = option("retryInterval") or _params?.retryInterval or "1m"
_timeout: str = option("timeout") or _params?.timeout or "10m"
_sourceRefName: str = option("sourceRefName") or _params?.sourceRefName or "flux-infra"
_sourceRefKind: str = option("sourceRefKind") or _params?.sourceRefKind or "GitRepository"
_path: str = option("path") or _params?.path or "./infra/vault"

# Vault Configuration
_vault_namespace: str = option("vault_namespace") or _params?.vault_namespace or "vault"
_vault_version: str = option("vault_version") or _params?.vault_version or "1.9.0"
_storage_class: str = option("storage_class") or _params?.storage_class or "local-path"
_gateway_name: str = option("gateway_name") or _params?.gateway_name or "k3s-infra-gateway"
_gateway_namespace: str = option("gateway_namespace") or _params?.gateway_namespace or "default"
_vault_hostname: str = option("vault_hostname") or _params?.vault_hostname or "vault"
_vault_domain: str = option("vault_domain") or _params?.vault_domain or "k3s-infra.sthings-vsphere.labul.sva.de"

# DependsOn
_dependsOnName: str = option("dependsOnName") or _params?.dependsOnName or "cilium-gateway"

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
            VAULT_NAMESPACE = _vault_namespace
            VAULT_VERSION = _vault_version
            STORAGE_CLASS = _storage_class
            GATEWAY_NAME = _gateway_name
            GATEWAY_NAMESPACE = _gateway_namespace
            VAULT_HOSTNAME = _vault_hostname
            VAULT_DOMAIN = _vault_domain
        }
    }
}
