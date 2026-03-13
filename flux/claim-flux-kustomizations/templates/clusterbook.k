"""
Clusterbook Kustomization Template

Generates a Flux Kustomization for deploying Clusterbook with postBuild substitutions
and an optional substituteFrom Secret reference for sensitive variables.

Usage:
    kcl run templates/clusterbook.k -D name=clusterbook -D CLUSTERBOOK_VERSION=v1.11.0
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ks?.spec or {}

# Common parameters
_name = _spec?.name or option("name") or "clusterbook"
_namespace = _spec?.namespace or option("namespace") or "flux-system"
_interval = _spec?.interval or option("interval") or "1h"
_retryInterval = _spec?.retryInterval or option("retryInterval") or "1m"
_timeout = _spec?.timeout or option("timeout") or "5m"
_prune = _spec?.prune or option("prune") or True
_wait = True

# Source reference parameters
_sourceRefKind = _spec?.sourceRefKind or option("sourceRefKind") or "GitRepository"
_sourceRefName = _spec?.sourceRefName or option("sourceRefName") or "stuttgart-things-flux"
_path = _spec?.path or option("path") or "./apps/clusterbook"

# Clusterbook-specific parameters
_clusterbookNamespace = _spec?.CLUSTERBOOK_NAMESPACE or option("CLUSTERBOOK_NAMESPACE") or "clusterbook"
_clusterbookVersion = _spec?.CLUSTERBOOK_VERSION or option("CLUSTERBOOK_VERSION") or "v1.11.0"
_clusterbookHostname = _spec?.CLUSTERBOOK_HOSTNAME or option("CLUSTERBOOK_HOSTNAME") or "clusterbook"
_gatewayName = _spec?.GATEWAY_NAME or option("GATEWAY_NAME") or "movie-scripts2-gateway"
_gatewayNamespace = _spec?.GATEWAY_NAMESPACE or option("GATEWAY_NAMESPACE") or "default"
_domain = _spec?.DOMAIN or option("DOMAIN") or "movie-scripts2.sthings-vsphere.labul.sva.de"
_pdnsEnabled = _spec?.PDNS_ENABLED or option("PDNS_ENABLED") or "true"
_pdnsUrl = _spec?.PDNS_URL or option("PDNS_URL") or "https://pdns.sthings-vsphere.labul.sva.de"
_pdnsZone = _spec?.PDNS_ZONE or option("PDNS_ZONE") or "sthings.io"

# substituteFrom secret name
_secretName = _spec?.secretName or option("secretName") or "clusterbook-pdns-vars"

# Build substitutions map
_substitute = {
    CLUSTERBOOK_NAMESPACE = _clusterbookNamespace
    CLUSTERBOOK_VERSION = _clusterbookVersion
    CLUSTERBOOK_HOSTNAME = _clusterbookHostname
    GATEWAY_NAME = _gatewayName
    GATEWAY_NAMESPACE = _gatewayNamespace
    DOMAIN = _domain
    PDNS_ENABLED = _pdnsEnabled
    PDNS_URL = _pdnsUrl
    PDNS_ZONE = _pdnsZone
}

# Clusterbook Kustomization
flux.Kustomization {
    metadata = v1.ObjectMeta {
        name = _name
        namespace = _namespace
        annotations = {
            "managed-by": "kcl-flux-kustomizations"
            "template": "clusterbook"
        }
        labels = {
            "app.kubernetes.io/managed-by": "flux"
            "kustomization.stuttgart-things.com/type": "app"
        }
    }
    spec = flux.KustomizeToolkitFluxcdIoV1KustomizationSpec {
        interval = _interval
        retryInterval = _retryInterval
        timeout = _timeout
        prune = _prune
        wait = _wait

        sourceRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecSourceRef {
            kind = _sourceRefKind
            name = _sourceRefName
        }

        path = _path

        postBuild = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecPostBuild {
            substitute = _substitute
            substituteFrom = [
                flux.KustomizeToolkitFluxcdIoV1KustomizationSpecPostBuildSubstituteFromItems0 {
                    kind = "Secret"
                    name = _secretName
                }
            ]
        }
    }
}
