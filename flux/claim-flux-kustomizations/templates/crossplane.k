"""
Crossplane Kustomization Template

Generates a Flux Kustomization for deploying Crossplane with provider configurations.

Usage:
    kcl run templates/crossplane.k -D name=crossplane -D sourceRefName=flux-apps -D path=./cicd/crossplane
    kcl run templates/crossplane.k -D crossplaneVersion=2.1.3 -D terraformProviderVersion=v1.0.5
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ks?.spec or {}

# Common parameters
_name = _spec?.name or option("name") or "crossplane"
_namespace = _spec?.namespace or option("namespace") or "flux-system"
_interval = _spec?.interval or option("interval") or "1h"
_retryInterval = _spec?.retryInterval or option("retryInterval") or "1m"
_timeout = _spec?.timeout or option("timeout") or "5m"
_prune = _spec?.prune or option("prune") or True
_wait = True  # Crossplane deployments always wait
_force = _spec?.force or option("force") or False
_suspend = _spec?.suspend or option("suspend") or False

# Source reference parameters
_sourceRefKind = _spec?.sourceRefKind or option("sourceRefKind") or "GitRepository"
_sourceRefName = _spec?.sourceRefName or option("sourceRefName") or "flux-apps"
_sourceRefNamespace = _spec?.sourceRefNamespace or option("sourceRefNamespace") or ""
_path = _spec?.path or option("path") or "./cicd/crossplane"

# Target namespace
_targetNamespace = _spec?.targetNamespace or option("targetNamespace") or ""

# Dependencies (comma-separated list of names)
_dependsOnNamesStr = _spec?.dependsOnNames or option("dependsOnNames") or ""
_dependsOnNamespace = _spec?.dependsOnNamespace or option("dependsOnNamespace") or ""

# Crossplane-specific parameters
_crossplaneNamespace = _spec?.crossplaneNamespace or option("crossplaneNamespace") or "crossplane-system"
_crossplaneVersion = _spec?.crossplaneVersion or option("crossplaneVersion") or "2.1.3"

# Terraform Provider parameters
_terraformConfigName = _spec?.terraformConfigName or option("terraformConfigName") or "terraform-runtime-config"
_terraformPoll = _spec?.terraformPoll or option("terraformPoll") or "30s"
_terraformProviderImage = _spec?.terraformProviderImage or option("terraformProviderImage") or "ghcr.io/stuttgart-things/sthings-cptf:1.14.3"
_terraformProviderVersion = _spec?.terraformProviderVersion or option("terraformProviderVersion") or "v1.0.5"
_terraformReconcileRate = _spec?.terraformReconcileRate or option("terraformReconcileRate") or "10"
_terraformS3SecretName = _spec?.terraformS3SecretName or option("terraformS3SecretName") or "terraform-s3"

# Helm Provider parameters
_helmProviderVersion = _spec?.helmProviderVersion or option("helmProviderVersion") or "v1.0.6"

# K8s Provider parameters
_k8sProviderVersion = _spec?.k8sProviderVersion or option("k8sProviderVersion") or "v1.2.0"

# KubeConfig for remote cluster
_kubeConfigSecretRef = _spec?.kubeConfigSecretRef or option("kubeConfigSecretRef") or ""
_kubeConfigSecretKey = _spec?.kubeConfigSecretKey or option("kubeConfigSecretKey") or ""

# Service account
_serviceAccountName = _spec?.serviceAccountName or option("serviceAccountName") or ""

# Helper: parse comma-separated dependency names to list
_dependsOnNames = [name.strip() for name in _dependsOnNamesStr.split(",") if name.strip()] if _dependsOnNamesStr else []

# Build substitutions map
_substitute = {
    CROSSPLANE_NAMESPACE = _crossplaneNamespace
    CROSSPLANE_VERSION = _crossplaneVersion
    CROSSPLANE_TERRAFORM_CONFIG_NAME = _terraformConfigName
    CROSSPLANE_TERRAFORM_POLL = _terraformPoll
    CROSSPLANE_TERRAFORM_PROVIDER_IMAGE = _terraformProviderImage
    CROSSPLANE_TERRAFORM_PROVIDER_VERSION = _terraformProviderVersion
    CROSSPLANE_TERRAFORM_RECONCILE_RATE = _terraformReconcileRate
    CROSSPLANE_TERRAFORM_S3_SECRET_NAME = _terraformS3SecretName
    CROSSPLANE_HELM_PROVIDER_VERSION = _helmProviderVersion
    CROSSPLANE_K8S_PROVIDER_VERSION = _k8sProviderVersion
}

# Crossplane Kustomization
flux.Kustomization {
    metadata = v1.ObjectMeta {
        name = _name
        namespace = _namespace
        annotations = {
            "managed-by": "kcl-flux-kustomizations"
            "template": "crossplane"
        }
        labels = {
            "app.kubernetes.io/managed-by": "flux"
            "kustomization.stuttgart-things.com/type": "crossplane"
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
    }
}
