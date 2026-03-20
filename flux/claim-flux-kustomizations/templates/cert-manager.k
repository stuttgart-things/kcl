"""
Cert-Manager Kustomization Template

Generates a Flux Kustomization for cert-manager deployment with
wait enabled, prune, and post-build variable substitution.

Usage:
    kcl run templates/cert-manager.k -D sourceRefName=flux-infra
    kcl run templates/cert-manager.k -D sourceRefName=flux-infra -D certManagerVersion=v1.19.1
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ks?.spec or {}

# Common parameters
_name = _spec?.name or option("name") or "cert-manager"
_namespace = _spec?.namespace or option("namespace") or "flux-system"
_interval = _spec?.interval or option("interval") or "1h"
_retryInterval = _spec?.retryInterval or option("retryInterval") or "1m"
_timeout = _spec?.timeout or option("timeout") or "5m"
_prune = _spec?.prune or option("prune") or True
_wait = True  # Cert-manager always waits
_force = _spec?.force or option("force") or False
_suspend = _spec?.suspend or option("suspend") or False

# Source reference parameters
_sourceRefKind = _spec?.sourceRefKind or option("sourceRefKind") or "GitRepository"
_sourceRefName = _spec?.sourceRefName or option("sourceRefName") or "flux-infra"
_sourceRefNamespace = _spec?.sourceRefNamespace or option("sourceRefNamespace") or ""
_path = _spec?.path or option("path") or "./infra/cert-manager/components/install"

# Target namespace
_targetNamespace = _spec?.targetNamespace or option("targetNamespace") or ""

# Dependencies (comma-separated list of names)
_dependsOnNamesStr = _spec?.dependsOnNames or option("dependsOnNames") or ""
_dependsOnNamespace = _spec?.dependsOnNamespace or option("dependsOnNamespace") or ""

# Cert-manager specific substitution parameters
_certManagerNamespace = _spec?.certManagerNamespace or option("certManagerNamespace") or "cert-manager"
_certManagerVersion = _spec?.certManagerVersion or option("certManagerVersion") or "v1.19.1"
_certManagerInstallCrds = _spec?.certManagerInstallCrds or option("certManagerInstallCrds") or "true"

# Additional post-build substitutions (comma-separated key=value pairs)
_substituteStr = _spec?.substitute or option("substitute") or ""

# Decryption
_decryptionProvider = _spec?.decryptionProvider or option("decryptionProvider") or ""
_decryptionSecretRef = _spec?.decryptionSecretRef or option("decryptionSecretRef") or ""

# KubeConfig for remote cluster
_kubeConfigSecretRef = _spec?.kubeConfigSecretRef or option("kubeConfigSecretRef") or ""
_kubeConfigSecretKey = _spec?.kubeConfigSecretKey or option("kubeConfigSecretKey") or ""

# Service account
_serviceAccountName = _spec?.serviceAccountName or option("serviceAccountName") or ""

# Common metadata
_commonLabelsStr = _spec?.commonLabels or option("commonLabels") or ""
_commonAnnotationsStr = _spec?.commonAnnotations or option("commonAnnotations") or ""

# Helper: parse comma-separated dependency names to list
_dependsOnNames = [name.strip() for name in _dependsOnNamesStr.split(",") if name.strip()] if _dependsOnNamesStr else []

# Helper: parse comma-separated key=value pairs to dict
_parseKeyValuePairs = lambda s: str -> {str:str} {
    {kv.split("=")[0].strip(): kv.split("=")[1].strip() for kv in s.split(",") if kv and "=" in kv}
}

# Build substitution map: cert-manager vars + any additional substitutions
_additionalSubstitute = _parseKeyValuePairs(_substituteStr) if _substituteStr else {}
_substitute = {
    CERT_MANAGER_NAMESPACE = _certManagerNamespace
    CERT_MANAGER_VERSION = _certManagerVersion
    CERT_MANAGER_INSTALL_CRDS = _certManagerInstallCrds
} | _additionalSubstitute

_commonLabels = _parseKeyValuePairs(_commonLabelsStr) if _commonLabelsStr else {}
_commonAnnotations = _parseKeyValuePairs(_commonAnnotationsStr) if _commonAnnotationsStr else {}

# Cert-Manager Kustomization
flux.Kustomization {
    metadata = v1.ObjectMeta {
        name = _name
        namespace = _namespace
        annotations = {
            "managed-by": "kcl-flux-kustomizations"
            "template": "cert-manager"
        }
        labels = {
            "app.kubernetes.io/managed-by": "flux"
            "kustomization.stuttgart-things.com/type": "infrastructure"
        }
    }
    spec = flux.KustomizeToolkitFluxcdIoV1KustomizationSpec {
        interval = _interval
        retryInterval = _retryInterval
        timeout = _timeout
        prune = _prune
        wait = _wait
        force = _force
        suspend = _suspend

        sourceRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecSourceRef {
            kind = _sourceRefKind
            name = _sourceRefName
            if _sourceRefNamespace:
                namespace = _sourceRefNamespace
        }

        path = _path

        if _targetNamespace:
            targetNamespace = _targetNamespace

        if _dependsOnNames:
            dependsOn = [
                flux.KustomizeToolkitFluxcdIoV1KustomizationSpecDependsOnItems0 {
                    name = depName
                    if _dependsOnNamespace:
                        namespace = _dependsOnNamespace
                }
                for depName in _dependsOnNames
            ]

        postBuild = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecPostBuild {
            substitute = _substitute
        }

        if _decryptionProvider == "sops" and _decryptionSecretRef:
            decryption = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecDecryption {
                provider = "sops"
                secretRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecDecryptionSecretRef {
                    name = _decryptionSecretRef
                }
            }

        if _kubeConfigSecretRef:
            kubeConfig = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecKubeConfig {
                secretRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecKubeConfigSecretRef {
                    name = _kubeConfigSecretRef
                    if _kubeConfigSecretKey:
                        key = _kubeConfigSecretKey
                }
            }

        if _serviceAccountName:
            serviceAccountName = _serviceAccountName

        if _commonLabels or _commonAnnotations:
            commonMetadata = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecCommonMetadata {
                if _commonLabels:
                    labels = _commonLabels
                if _commonAnnotations:
                    annotations = _commonAnnotations
            }
    }
}
