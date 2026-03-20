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

# Vault HTTPRoute specific parameters (for vault-httproute template)
_vaultHttprouteNamespace = _spec?.vaultHttprouteNamespace or option("vaultHttprouteNamespace") or "vault"
_vaultHttprouteGatewayName = _spec?.vaultHttprouteGatewayName or option("vaultHttprouteGatewayName") or "gateway"
_vaultHttprouteGatewayNamespace = _spec?.vaultHttprouteGatewayNamespace or option("vaultHttprouteGatewayNamespace") or "default"
_vaultHttprouteHostname = _spec?.vaultHttprouteHostname or option("vaultHttprouteHostname") or "vault"
_vaultHttprouteDomain = _spec?.vaultHttprouteDomain or option("vaultHttprouteDomain") or ""

# Vault Autounseal specific parameters (for vault-autounseal template)
_vaultAutounsealNamespace = _spec?.vaultAutounsealNamespace or option("vaultAutounsealNamespace") or "vault"
_unsealHelmRepoUrl = _spec?.unsealHelmRepoUrl or option("unsealHelmRepoUrl") or "https://pytoshka.github.io/vault-autounseal"
_vaultAutounsealVersion = _spec?.vaultAutounsealVersion or option("vaultAutounsealVersion") or "0.5.3"
_vaultAutounsealUrl = _spec?.vaultAutounsealUrl or option("vaultAutounsealUrl") or "http://vault-server.vault.svc:8200"
_vaultAutounsealLabelSelector = _spec?.vaultAutounsealLabelSelector or option("vaultAutounsealLabelSelector") or "app.kubernetes.io/component=server"

# Vault specific parameters (for vault template)
_vaultVersion = _spec?.vaultVersion or option("vaultVersion") or "1.9.0"
_vaultNamespace = _spec?.vaultNamespace or option("vaultNamespace") or "vault"
_vaultRegistry = _spec?.vaultRegistry or option("vaultRegistry") or "ghcr.io"
_vaultRepository = _spec?.vaultRepository or option("vaultRepository") or "stuttgart-things/vault"
_vaultTag = _spec?.vaultTag or option("vaultTag") or "1.20.2-debian-12-r2"
_vaultPullPolicy = _spec?.vaultPullPolicy or option("vaultPullPolicy") or "Always"
_vaultIngressEnabled = _spec?.vaultIngressEnabled or option("vaultIngressEnabled") or "false"
_vaultIngressClassName = _spec?.vaultIngressClassName or option("vaultIngressClassName") or "nginx"
_vaultStorageClass = _spec?.vaultStorageClass or option("vaultStorageClass") or "local-path"
_vaultInjectorEnabled = _spec?.vaultInjectorEnabled or option("vaultInjectorEnabled") or "true"
_vaultInjectorRepository = _spec?.vaultInjectorRepository or option("vaultInjectorRepository") or "stuttgart-things/vault-k8s"
_vaultInjectorTag = _spec?.vaultInjectorTag or option("vaultInjectorTag") or "1.7.0-debian-12-r4"
_vaultInjectorPullPolicy = _spec?.vaultInjectorPullPolicy or option("vaultInjectorPullPolicy") or "Always"
_vaultEnableVolumePermissions = _spec?.vaultEnableVolumePermissions or option("vaultEnableVolumePermissions") or "true"
_vaultOsShellRepository = _spec?.vaultOsShellRepository or option("vaultOsShellRepository") or "stuttgart-things/os-shell"
_vaultOsShellTag = _spec?.vaultOsShellTag or option("vaultOsShellTag") or "12-debian-12-r50"
_vaultOsShellPullPolicy = _spec?.vaultOsShellPullPolicy or option("vaultOsShellPullPolicy") or "Always"
_vaultIngressHostname = _spec?.vaultIngressHostname or option("vaultIngressHostname") or "vault"
_vaultIngressDomain = _spec?.vaultIngressDomain or option("vaultIngressDomain") or ""
_vaultIssuerName = _spec?.vaultIssuerName or option("vaultIssuerName") or "vault-pki"
_vaultIssuerKind = _spec?.vaultIssuerKind or option("vaultIssuerKind") or "ClusterIssuer"

# OpenEBS specific parameters (for openebs template)
_openebsVersion = _spec?.openebsVersion or option("openebsVersion") or "4.2.0"
_openebsVolumesnapshotsEnabled = _spec?.openebsVolumesnapshotsEnabled or option("openebsVolumesnapshotsEnabled") or "false"
_openebsCsiNodeInitContainersEnabled = _spec?.openebsCsiNodeInitContainersEnabled or option("openebsCsiNodeInitContainersEnabled") or "false"
_openebsLocalLvmEnabled = _spec?.openebsLocalLvmEnabled or option("openebsLocalLvmEnabled") or "false"
_openebsLocalZfsEnabled = _spec?.openebsLocalZfsEnabled or option("openebsLocalZfsEnabled") or "false"
_openebsReplicatedMayastorEnabled = _spec?.openebsReplicatedMayastorEnabled or option("openebsReplicatedMayastorEnabled") or "false"

# Cilium Gateway specific parameters (for cilium-gateway template)
_ciliumGatewayName = _spec?.ciliumGatewayName or option("ciliumGatewayName") or "gateway"
_ciliumGatewayNamespace = _spec?.ciliumGatewayNamespace or option("ciliumGatewayNamespace") or "default"
_ciliumGatewayDomain = _spec?.ciliumGatewayDomain or option("ciliumGatewayDomain") or ""
_ciliumGatewayTlsSecret = _spec?.ciliumGatewayTlsSecret or option("ciliumGatewayTlsSecret") or ""

# Cert-manager selfsigned specific parameters (for cert-manager-selfsigned template)
_certManagerSelfsignedDomain = _spec?.certManagerSelfsignedDomain or option("certManagerSelfsignedDomain") or ""
_certManagerSelfsignedSecretName = _spec?.certManagerSelfsignedSecretName or option("certManagerSelfsignedSecretName") or ""
_certManagerSelfsignedCertName = _spec?.certManagerSelfsignedCertName or option("certManagerSelfsignedCertName") or ""
_certManagerSelfsignedCertNamespace = _spec?.certManagerSelfsignedCertNamespace or option("certManagerSelfsignedCertNamespace") or "default"
_certManagerSelfsignedIssuer = _spec?.certManagerSelfsignedIssuer or option("certManagerSelfsignedIssuer") or "vault-pki"

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
_substitute: {str:str} = _parseKeyValuePairs(_substituteStr) if _substituteStr else {}
_commonLabels: {str:str} = _parseKeyValuePairs(_commonLabelsStr) if _commonLabelsStr else {}
_commonAnnotations: {str:str} = _parseKeyValuePairs(_commonAnnotationsStr) if _commonAnnotationsStr else {}

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
                substitute = {
                    "CLUSTERBOOK_NAMESPACE": str(_clusterbookNamespace)
                    "CLUSTERBOOK_VERSION": str(_clusterbookVersion)
                    "CLUSTERBOOK_HOSTNAME": str(_clusterbookHostname)
                    "GATEWAY_NAME": str(_gatewayName)
                    "GATEWAY_NAMESPACE": str(_gatewayNamespace)
                    "DOMAIN": str(_domain)
                    "FLUX_SOURCE_API_VERSION": _fluxSourceApiVersion
                }
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


# Template: Vault HTTPRoute (gateway route for vault)
if _templateName == "vault-httproute":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "vault-httproute"
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "vault-httproute"
            }
            labels = {
                "app.kubernetes.io/managed-by": "flux"
                "kustomization.stuttgart-things.com/type": "app"
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
                name = _sourceRefName if _sourceRefName else "flux-apps"
                if _sourceRefNamespace:
                    namespace = _sourceRefNamespace
            }

            path = _path if _path != "./" else "./apps/vault/httproute"

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
                substitute = {
                    "VAULT_NAMESPACE": str(_vaultHttprouteNamespace)
                    "GATEWAY_NAME": str(_vaultHttprouteGatewayName)
                    "GATEWAY_NAMESPACE": str(_vaultHttprouteGatewayNamespace)
                    "VAULT_HOSTNAME": str(_vaultHttprouteHostname)
                    "VAULT_DOMAIN": str(_vaultHttprouteDomain)
                }
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
        }
    }

# Template: Vault Autounseal (app deployment with autounseal config)
if _templateName == "vault-autounseal":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "vault-autounseal"
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "vault-autounseal"
            }
            labels = {
                "app.kubernetes.io/managed-by": "flux"
                "kustomization.stuttgart-things.com/type": "app"
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
                name = _sourceRefName if _sourceRefName else "flux-apps"
                if _sourceRefNamespace:
                    namespace = _sourceRefNamespace
            }

            path = _path if _path != "./" else "./apps/vault/autounseal"

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
                substitute = {
                    "VAULT_NAMESPACE": str(_vaultAutounsealNamespace)
                    "UNSEAL_HELM_REPO_URL": str(_unsealHelmRepoUrl)
                    "VAULT_AUTOUNSEAL_VERSION": str(_vaultAutounsealVersion)
                    "VAULT_AUTOUNSEAL_URL": str(_vaultAutounsealUrl)
                    "VAULT_AUTOUNSEAL_LABEL_SELECTOR": str(_vaultAutounsealLabelSelector)
                }
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
        }
    }

# Template: Vault (app deployment with image and ingress substitutions)
if _templateName == "vault":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "vault"
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "vault"
            }
            labels = {
                "app.kubernetes.io/managed-by": "flux"
                "kustomization.stuttgart-things.com/type": "app"
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
                name = _sourceRefName if _sourceRefName else "flux-apps"
                if _sourceRefNamespace:
                    namespace = _sourceRefNamespace
            }

            path = _path if _path != "./" else "./apps/vault"

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
                substitute = {
                    "VAULT_VERSION": str(_vaultVersion)
                    "VAULT_NAMESPACE": str(_vaultNamespace)
                    "REGISTRY": str(_vaultRegistry)
                    "REPOSITORY": str(_vaultRepository)
                    "TAG": str(_vaultTag)
                    "PULL_POLICY": str(_vaultPullPolicy)
                    "INGRESS_ENABLED": str(_vaultIngressEnabled)
                    "INGRESS_CLASS_NAME": str(_vaultIngressClassName)
                    "STORAGE_CLASS": str(_vaultStorageClass)
                    "INJECTOR_ENABLED": str(_vaultInjectorEnabled)
                    "INJECTOR_REPOSITORY": str(_vaultInjectorRepository)
                    "INJECTOR_TAG": str(_vaultInjectorTag)
                    "INJECTOR_PULL_POLICY": str(_vaultInjectorPullPolicy)
                    "ENABLE_VOLUME_PERMISSIONS": str(_vaultEnableVolumePermissions)
                    "OS_SHELL_REPOSITORY": str(_vaultOsShellRepository)
                    "OS_SHELL_TAG": str(_vaultOsShellTag)
                    "OS_SHELL_PULL_POLICY": str(_vaultOsShellPullPolicy)
                    "VAULT_INGRESS_HOSTNAME": str(_vaultIngressHostname)
                    "VAULT_INGRESS_DOMAIN": str(_vaultIngressDomain)
                    "ISSUER_NAME": str(_vaultIssuerName)
                    "ISSUER_KIND": str(_vaultIssuerKind)
                }
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
        }
    }

# Template: OpenEBS (infrastructure with openebs substitutions)
if _templateName == "openebs":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "openebs"
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "openebs"
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

            path = _path if _path != "./" else "./infra/openebs"

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
                substitute = {
                    "VERSION": str(_openebsVersion)
                    "VOLUMESNAPSHOTS_ENABLED": str(_openebsVolumesnapshotsEnabled)
                    "CSI_NODE_INIT_CONTAINERS_ENABLED": str(_openebsCsiNodeInitContainersEnabled)
                    "LOCAL_LVM_ENABLED": str(_openebsLocalLvmEnabled)
                    "LOCAL_ZFS_ENABLED": str(_openebsLocalZfsEnabled)
                    "REPLICATED_MAYASTOR_ENABLED": str(_openebsReplicatedMayastorEnabled)
                }
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
        }
    }

# Template: Cilium Gateway (infrastructure with gateway substitutions)
if _templateName == "cilium-gateway":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "cilium-gateway"
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "cilium-gateway"
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

            path = _path if _path != "./" else "./infra/cilium/components/gateway"

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
                substitute = {
                    "CILIUM_GATEWAY_NAME": str(_ciliumGatewayName)
                    "CILIUM_GATEWAY_NAMESPACE": str(_ciliumGatewayNamespace)
                    "CILIUM_GATEWAY_DOMAIN": str(_ciliumGatewayDomain)
                    "CILIUM_GATEWAY_TLS_SECRET": str(_ciliumGatewayTlsSecret)
                }
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
        }
    }

# Template: Cert-Manager Selfsigned (certificate with selfsigned issuer)
if _templateName == "cert-manager-selfsigned":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "cert-manager-selfsigned"
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "cert-manager-selfsigned"
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

            path = _path if _path != "./" else "./infra/cert-manager/components/selfsigned"

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
                substitute = {
                    "CERT_MANAGER_NAMESPACE": str(_certManagerNamespace)
                    "CERT_MANAGER_SELFSIGNED_DOMAIN": str(_certManagerSelfsignedDomain)
                    "CERT_MANAGER_SELFSIGNED_SECRET_NAME": str(_certManagerSelfsignedSecretName)
                    "CERT_MANAGER_SELFSIGNED_CERT_NAME": str(_certManagerSelfsignedCertName)
                    "CERT_MANAGER_SELFSIGNED_CERT_NAMESPACE": str(_certManagerSelfsignedCertNamespace)
                    "CERT_MANAGER_SELFSIGNED_ISSUER": str(_certManagerSelfsignedIssuer)
                }
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
        }
    }

# Template: Cert-Manager (infrastructure with cert-manager substitutions)
if _templateName == "cert-manager":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "cert-manager-install"
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
                substitute = {
                    "CERT_MANAGER_NAMESPACE": str(_certManagerNamespace)
                    "CERT_MANAGER_VERSION": str(_certManagerVersion)
                    "CERT_MANAGER_INSTALL_CRDS": str(_certManagerInstallCrds)
                }
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
