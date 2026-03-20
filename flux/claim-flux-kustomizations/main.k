"""
Flux Kustomization KCL Module - Entry Point

This module provides templates for generating Flux Kustomization resources
to deploy applications and infrastructure using GitOps workflows.

Templates:
- gitops: Basic GitOps Kustomization with common defaults
- infrastructure: Infrastructure Kustomization with dependencies and health checks
- cert-manager: Cert-manager deployment with version/namespace substitutions
- crossplane: Crossplane deployment with provider configurations
- gitrepository: Flux GitRepository source for use by Kustomizations

Usage via main.k:
    kcl run . -D templateName=gitops -D name=my-app -D sourceRefName=my-repo -D path=./manifests
    kcl run . -D templateName=infrastructure -D name=infra -D sourceRefName=infra-repo -D dependsOnNames="cert-manager,ingress-nginx"
    kcl run . -D templateName=crossplane -D sourceRefName=flux-apps -D crossplaneVersion=2.1.3
    kcl run . -D templateName=clusterbook -D name=clusterbook -D CLUSTERBOOK_VERSION=v1.11.0
    kcl run . -D templateName=gitrepository -D name=flux-infra -D url=https://github.com/stuttgart-things/flux.git

Usage via standalone templates:
    kcl run templates/gitops.k -D name=my-app -D sourceRefName=my-repo
    kcl run templates/infrastructure.k -D name=infra -D sourceRefName=infra-repo
    kcl run templates/crossplane.k -D sourceRefName=flux-apps -D terraformProviderVersion=v1.0.5
    kcl run templates/gitrepository.k -D name=flux-apps -D url=https://github.com/stuttgart-things/flux.git
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux
import v1.source_toolkit_fluxcd_io_v1_git_repository as source

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ks?.spec or {}

# Template selector
_templateName = _spec?.templateName or option("templateName") or _params?.templateName or "gitops"

# Common parameters
_name = _spec?.name or option("name") or "flux-kustomization"
_namespace = _spec?.namespace or option("namespace") or "flux-system"
_interval = _spec?.interval or option("interval") or "5m"
_retryInterval = _spec?.retryInterval or option("retryInterval") or ""
_timeout = _spec?.timeout or option("timeout") or ""
_prune = _spec?.prune or option("prune") or True
_wait = _spec?.wait or option("wait") or False
_force = _spec?.force or option("force") or False
_suspend = _spec?.suspend or option("suspend") or False

# Source reference parameters
_sourceRefKind = _spec?.sourceRefKind or option("sourceRefKind") or "GitRepository"
_sourceRefName = _spec?.sourceRefName or option("sourceRefName") or ""
_sourceRefNamespace = _spec?.sourceRefNamespace or option("sourceRefNamespace") or ""
_path = _spec?.path or option("path") or "./"

# Target namespace
_targetNamespace = _spec?.targetNamespace or option("targetNamespace") or ""

# Name prefix/suffix
_namePrefix = _spec?.namePrefix or option("namePrefix") or ""
_nameSuffix = _spec?.nameSuffix or option("nameSuffix") or ""

# Dependencies (comma-separated list of names)
_dependsOnNamesStr = _spec?.dependsOnNames or option("dependsOnNames") or ""
_dependsOnNamespace = _spec?.dependsOnNamespace or option("dependsOnNamespace") or ""

# Post-build substitutions (comma-separated key=value pairs)
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

# GitRepository-specific parameters (for gitrepository template)
_gitRepoUrl = _spec?.url or option("url") or "https://github.com/stuttgart-things/flux.git"
_gitRepoBranch = _spec?.branch or option("branch") or "main"
_gitRepoTag = _spec?.tag or option("tag") or ""
_gitRepoSemver = _spec?.semver or option("semver") or ""
_gitRepoCommit = _spec?.commit or option("commit") or ""
_gitRepoSecretRefName = _spec?.secretRefName or option("secretRefName") or ""

# Cert-manager specific parameters (for cert-manager template)
_certManagerNamespace = _spec?.certManagerNamespace or option("certManagerNamespace") or "cert-manager"
_certManagerVersion = _spec?.certManagerVersion or option("certManagerVersion") or "v1.19.1"
_certManagerInstallCrds = _spec?.certManagerInstallCrds or option("certManagerInstallCrds") or "true"

# Crossplane-specific parameters (for crossplane template)
_crossplaneNamespace = _spec?.crossplaneNamespace or option("crossplaneNamespace") or "crossplane-system"
_crossplaneVersion = _spec?.crossplaneVersion or option("crossplaneVersion") or "2.1.3"
_terraformConfigName = _spec?.terraformConfigName or option("terraformConfigName") or "terraform-runtime-config"
_terraformPoll = _spec?.terraformPoll or option("terraformPoll") or "30s"
_terraformProviderImage = _spec?.terraformProviderImage or option("terraformProviderImage") or "ghcr.io/stuttgart-things/sthings-cptf:1.14.3"
_terraformProviderVersion = _spec?.terraformProviderVersion or option("terraformProviderVersion") or "v1.0.5"
_terraformReconcileRate = _spec?.terraformReconcileRate or option("terraformReconcileRate") or "10"
_terraformS3SecretName = _spec?.terraformS3SecretName or option("terraformS3SecretName") or "terraform-s3"
_helmProviderVersion = _spec?.helmProviderVersion or option("helmProviderVersion") or "v1.0.6"
_k8sProviderVersion = _spec?.k8sProviderVersion or option("k8sProviderVersion") or "v1.2.0"

# Helper: parse comma-separated dependency names to list
_dependsOnNames = [name.strip() for name in _dependsOnNamesStr.split(",") if name.strip()] if _dependsOnNamesStr else []

# Helper: parse comma-separated key=value pairs to dict
_parseKeyValuePairs = lambda s: str -> {str:str} {
    {kv.split("=")[0].strip(): kv.split("=")[1].strip() for kv in s.split(",") if kv and "=" in kv}
}
_substitute = _parseKeyValuePairs(_substituteStr) if _substituteStr else {}
_commonLabels = _parseKeyValuePairs(_commonLabelsStr) if _commonLabelsStr else {}
_commonAnnotations = _parseKeyValuePairs(_commonAnnotationsStr) if _commonAnnotationsStr else {}

# Template: GitOps (basic kustomization)
if _templateName == "gitops":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "gitops"
            }
            labels = {
                "app.kubernetes.io/managed-by": "flux"
                "kustomization.stuttgart-things.com/type": "gitops"
            }
        }
        spec = flux.KustomizeToolkitFluxcdIoV1KustomizationSpec {
            interval = _interval
            if _retryInterval:
                retryInterval = _retryInterval
            if _timeout:
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

            if _namePrefix:
                namePrefix = _namePrefix

            if _nameSuffix:
                nameSuffix = _nameSuffix

            if _dependsOnNames:
                dependsOn = [
                    flux.KustomizeToolkitFluxcdIoV1KustomizationSpecDependsOnItems0 {
                        name = depName
                        if _dependsOnNamespace:
                            namespace = _dependsOnNamespace
                    }
                    for depName in _dependsOnNames
                ]

            if _substitute:
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

# Template: Clusterbook (app deployment with postBuild substitutions and substituteFrom secret)
if _templateName == "clusterbook":
    # Clusterbook-specific parameters
    _clusterbookNamespace = option("CLUSTERBOOK_NAMESPACE") or "clusterbook"
    _clusterbookVersion = option("CLUSTERBOOK_VERSION") or "v1.11.0"
    _clusterbookHostname = option("CLUSTERBOOK_HOSTNAME") or "clusterbook"
    _gatewayName = option("GATEWAY_NAME") or ""
    _gatewayNamespace = option("GATEWAY_NAMESPACE") or "default"
    _domain = option("DOMAIN") or ""
    _fluxSourceApiVersion = "v1"
    _pdnsEnabled = str(option("PDNS_ENABLED") or "false").lower()
    _pdnsUrl = option("PDNS_URL") or ""
    _pdnsZone = option("PDNS_ZONE") or ""
    _secretName = option("secretName") or "clusterbook-pdns-vars"

    # Build base substitutions map
    _baseSubstitute = {
        CLUSTERBOOK_NAMESPACE = str(_clusterbookNamespace)
        CLUSTERBOOK_VERSION = str(_clusterbookVersion)
        CLUSTERBOOK_HOSTNAME = str(_clusterbookHostname)
        GATEWAY_NAME = str(_gatewayName)
        GATEWAY_NAMESPACE = str(_gatewayNamespace)
        DOMAIN = str(_domain)
        FLUX_SOURCE_API_VERSION = _fluxSourceApiVersion
    }

    # Conditionally add PDNS vars
    _pdnsSubstitute = {
        PDNS_ENABLED = _pdnsEnabled
        PDNS_URL = _pdnsUrl
        PDNS_ZONE = _pdnsZone
    } if _pdnsEnabled == "true" else {}

    _clusterbookSubstitute: {str:str} = _baseSubstitute | _pdnsSubstitute

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
            retryInterval = _retryInterval if _retryInterval else "1m"
            timeout = _timeout if _timeout else "5m"
            prune = _prune
            wait = True

            sourceRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecSourceRef {
                kind = _sourceRefKind
                name = _sourceRefName if _sourceRefName else "flux-apps"
            }

            path = _path if _path != "./" else "./apps/clusterbook"

            postBuild = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecPostBuild {
                substitute = _clusterbookSubstitute
                if _pdnsEnabled == "true":
                    substituteFrom = [
                        flux.KustomizeToolkitFluxcdIoV1KustomizationSpecPostBuildSubstituteFromItems0 {
                            kind = "Secret"
                            name = _secretName
                        }
                    ]
            }
        }
    }


# Template: Cert-Manager (infrastructure with cert-manager substitutions)
if _templateName == "cert-manager":
    # Build cert-manager substitution map + any additional substitutions
    _certManagerSubstitute: {str:str} = {
        CERT_MANAGER_NAMESPACE = _certManagerNamespace
        CERT_MANAGER_VERSION = _certManagerVersion
        CERT_MANAGER_INSTALL_CRDS = _certManagerInstallCrds
    } | _substitute

    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "cert-manager"
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
            interval = _interval if _interval != "5m" else "1h"
            retryInterval = _retryInterval if _retryInterval else "1m"
            timeout = _timeout if _timeout else "5m"
            prune = _prune
            wait = True
            force = _force
            suspend = _suspend

            sourceRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecSourceRef {
                kind = _sourceRefKind
                name = _sourceRefName if _sourceRefName else "flux-infra"
                if _sourceRefNamespace:
                    namespace = _sourceRefNamespace
            }

            path = _path if _path != "./" else "./infra/cert-manager/components/install"

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
                substitute = _certManagerSubstitute
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

# Template: Infrastructure (with wait, health checks, and dependencies)
if _templateName == "infrastructure":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "infrastructure"
            }
            labels = {
                "app.kubernetes.io/managed-by": "flux"
                "kustomization.stuttgart-things.com/type": "infrastructure"
            }
        }
        spec = flux.KustomizeToolkitFluxcdIoV1KustomizationSpec {
            interval = _interval
            retryInterval = _retryInterval if _retryInterval else "2m"
            timeout = _timeout if _timeout else "5m"
            prune = _prune
            wait = True  # Infrastructure always waits for resources to be ready
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

            if _namePrefix:
                namePrefix = _namePrefix

            if _nameSuffix:
                nameSuffix = _nameSuffix

            if _dependsOnNames:
                dependsOn = [
                    flux.KustomizeToolkitFluxcdIoV1KustomizationSpecDependsOnItems0 {
                        name = depName
                        if _dependsOnNamespace:
                            namespace = _dependsOnNamespace
                    }
                    for depName in _dependsOnNames
                ]

            if _substitute:
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

# Template: GitRepository (Flux source)
if _templateName == "gitrepository":
    source.GitRepository {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "gitrepository"
            }
            labels = {
                "app.kubernetes.io/managed-by": "flux"
            }
        }
        spec = source.SourceToolkitFluxcdIoV1GitRepositorySpec {
            url = _gitRepoUrl
            interval = _interval
            timeout = _timeout if _timeout else "60s"

            if _suspend:
                suspend = _suspend

            ref = source.SourceToolkitFluxcdIoV1GitRepositorySpecRef {
                if _gitRepoCommit:
                    commit = _gitRepoCommit
                elif _gitRepoSemver:
                    semver = _gitRepoSemver
                elif _gitRepoTag:
                    tag = _gitRepoTag
                else:
                    branch = _gitRepoBranch
            }

            if _gitRepoSecretRefName:
                secretRef = source.SourceToolkitFluxcdIoV1GitRepositorySpecSecretRef {
                    name = _gitRepoSecretRefName
                }
        }
    }
