"""
Flux HelmRelease KCL Module

This module provides simplified schemas and helper functions for creating
Flux HelmRelease resources using the generated CRD models.

Generated from: https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/helm-controller.yaml
CRD Version: Flux v2.7.2
Conversion Date: 2025-10-23
"""

import v2.helm_toolkit_fluxcd_io_v2_helm_release as helm
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as xhelm

# --- Simplified Schemas ---

schema SimpleHelmRelease:
    """
    Simplified Flux HelmRelease configuration with sensible defaults.

    Attributes:
    -----------
    name: str
        Name of the HelmRelease resource
    namespace: str
        Namespace where the HelmRelease will be created (default: flux-system)
    chart: ChartRef
        Helm chart reference
    interval: str
        Reconciliation interval (default: 5m)
    values: {str:}
        Helm values to override chart defaults
    targetNamespace: str
        Target namespace for Helm release installation
    dependsOn: [DependencyRef]
        List of HelmReleases/Kustomizations that must be ready first
    install: InstallConfig
        Installation configuration
    upgrade: UpgradeConfig
        Upgrade configuration
    """
    name: str
    namespace?: str = "flux-system"
    chart: ChartRef
    interval?: str = "5m"
    values?: {str:}
    targetNamespace?: str
    dependsOn?: [DependencyRef]
    install?: InstallConfig
    upgrade?: UpgradeConfig
    suspend?: bool = False
    timeout?: str = "5m"
    releaseName?: str
    storageNamespace?: str
    labels?: {str: str}
    annotations?: {str: str}

schema ChartRef:
    """
    Reference to a Helm chart.

    Attributes:
    -----------
    name: str
        Chart name
    version: str
        Chart version (optional, can use semver constraints)
    sourceRef: SourceRef
        Reference to the chart source (HelmRepository, GitRepository, Bucket)
    """
    name: str
    version?: str
    sourceRef: SourceRef

schema SourceRef:
    """
    Reference to a Flux Source resource.

    Attributes:
    -----------
    kind: str
        Source kind (HelmRepository, GitRepository, Bucket)
    name: str
        Name of the source
    namespace: str
        Namespace of the source (optional)
    """
    kind: "HelmRepository" | "GitRepository" | "Bucket"
    name: str
    namespace?: str

schema DependencyRef:
    """
    Reference to another HelmRelease or Kustomization that must be ready first.

    Attributes:
    -----------
    name: str
        Name of the resource to depend on
    namespace: str
        Namespace of the dependency (optional)
    """
    name: str
    namespace?: str

schema InstallConfig:
    """
    Helm install configuration.

    Attributes:
    -----------
    createNamespace: bool
        Create target namespace if it doesn't exist
    remediation: RemediationConfig
        Remediation configuration for install failures
    """
    createNamespace?: bool = True
    remediation?: RemediationConfig

schema UpgradeConfig:
    """
    Helm upgrade configuration.

    Attributes:
    -----------
    remediation: RemediationConfig
        Remediation configuration for upgrade failures
    cleanupOnFail: bool
        Cleanup resources on upgrade failure
    force: bool
        Force resource updates through delete/recreate
    """
    remediation?: RemediationConfig
    cleanupOnFail?: bool = False
    force?: bool = False

schema RemediationConfig:
    """
    Remediation configuration for install/upgrade failures.

    Attributes:
    -----------
    retries: int
        Number of retry attempts
    ignoreTestFailures: bool
        Ignore test failures during remediation
    """
    retries?: int = 0
    ignoreTestFailures?: bool = False

# --- Helper Functions ---

generateHelmRelease = lambda config: SimpleHelmRelease -> [helm.HelmRelease] {
    """
    Generate a Flux HelmRelease from simplified configuration.

    Parameters:
    -----------
    config: SimpleHelmRelease
        Simplified HelmRelease configuration

    Returns:
    --------
    [helm.HelmRelease]
        List containing the generated HelmRelease resource

    Example:
    --------
    myRelease = generateHelmRelease(SimpleHelmRelease {
        name = "nginx"
        chart = ChartRef {
            name = "nginx"
            version = "15.0.0"
            sourceRef = SourceRef {
                kind = "HelmRepository"
                name = "bitnami"
            }
        }
        values = {
            replicaCount = 3
        }
    })
    """
    [
        helm.HelmRelease {
            apiVersion = "helm.toolkit.fluxcd.io/v2"
            kind = "HelmRelease"
            metadata = {
                name = config.name
                namespace = config.namespace or "flux-system"
                labels = config.labels or {}
                annotations = config.annotations or {}
            }
            spec = {
                interval = config.interval or "5m"
                timeout = config.timeout or "5m"
                suspend = config.suspend if config.suspend != None else False
                releaseName = config.releaseName or config.name
                targetNamespace = config.targetNamespace or config.namespace or "flux-system"
                storageNamespace = config.storageNamespace
                chart = {
                    spec = {
                        chart = config.chart.name
                        version = config.chart.version
                        sourceRef = {
                            kind = config.chart.sourceRef.kind
                            name = config.chart.sourceRef.name
                            namespace = config.chart.sourceRef.namespace
                        } if config.chart.sourceRef.namespace else {
                            kind = config.chart.sourceRef.kind
                            name = config.chart.sourceRef.name
                        }
                    }
                }
                values = config.values or {}
                dependsOn = [
                    {
                        name = dep.name
                        namespace = dep.namespace
                    } if dep.namespace else {
                        name = dep.name
                    }
                    for dep in config.dependsOn
                ] if config.dependsOn else []
                install = {
                    createNamespace = config.install.createNamespace if config.install.createNamespace != None else True
                    remediation = {
                        retries = config.install.remediation.retries or 0
                        ignoreTestFailures = config.install.remediation.ignoreTestFailures if config.install.remediation.ignoreTestFailures != None else False
                    } if config.install.remediation else {
                        retries = 0
                    }
                } if config.install else {
                    createNamespace = True
                    remediation = {
                        retries = 0
                    }
                }
                upgrade = {
                    cleanupOnFail = config.upgrade.cleanupOnFail if config.upgrade.cleanupOnFail != None else False
                    force = config.upgrade.force if config.upgrade.force != None else False
                    remediation = {
                        retries = config.upgrade.remediation.retries or 0
                        ignoreTestFailures = config.upgrade.remediation.ignoreTestFailures if config.upgrade.remediation.ignoreTestFailures != None else False
                    } if config.upgrade.remediation else {
                        retries = 0
                    }
                } if config.upgrade else {
                    cleanupOnFail = False
                    remediation = {
                        retries = 0
                    }
                }
            }
        }
    ]
}

# --- Convenience Functions ---

helmReleaseFromRepo = lambda name: str, chartName: str, chartVersion: str, repoName: str, values: {str:} = {} -> [helm.HelmRelease] {
    """
    Quick helper to create a HelmRelease from a HelmRepository.

    Parameters:
    -----------
    name: str
        Name of the HelmRelease
    chartName: str
        Name of the Helm chart
    chartVersion: str
        Chart version
    repoName: str
        Name of the HelmRepository source
    values: {str:}
        Helm values (optional)

    Returns:
    --------
    [helm.HelmRelease]
        Generated HelmRelease resource

    Example:
    --------
    nginx = helmReleaseFromRepo("nginx", "nginx", "15.0.0", "bitnami", {
        replicaCount = 3
    })
    """
    generateHelmRelease(SimpleHelmRelease {
        name = name
        chart = ChartRef {
            name = chartName
            version = chartVersion
            sourceRef = SourceRef {
                kind = "HelmRepository"
                name = repoName
            }
        }
        values = values
    })
}

helmReleaseFromGit = lambda name: str, chartPath: str, gitRepoName: str, values: {str:} = {} -> [helm.HelmRelease] {
    """
    Quick helper to create a HelmRelease from a GitRepository.

    Parameters:
    -----------
    name: str
        Name of the HelmRelease
    chartPath: str
        Path to chart in Git repository
    gitRepoName: str
        Name of the GitRepository source
    values: {str:}
        Helm values (optional)

    Returns:
    --------
    [helm.HelmRelease]
        Generated HelmRelease resource

    Example:
    --------
    myChart = helmReleaseFromGit("my-app", "./charts/app", "my-repo", {
        environment = "production"
    })
    """
    generateHelmRelease(SimpleHelmRelease {
        name = name
        chart = ChartRef {
            name = chartPath
            sourceRef = SourceRef {
                kind = "GitRepository"
                name = gitRepoName
            }
        }
        values = values
    })
}

# --- Crossplane XR Helper ---

generateCrossplaneHelmRelease = lambda -> [helm.HelmRelease] {
    """
    Generate HelmRelease from Crossplane XR spec using standard variable pattern.

    Expects XR spec fields:
    - name: str (HelmRelease name)
    - namespace: str (optional, default: flux-system)
    - chartName: str
    - chartVersion: str (optional)
    - sourceKind: str (HelmRepository, GitRepository, OCIRepository)
    - sourceName: str
    - sourceNamespace: str (optional)
    - interval: str (optional, default: 5m)
    - values: {str:} (optional)
    - targetNamespace: str (optional)
    - releaseName: str (optional, defaults to name)
    - createNamespace: bool (optional, default: true)

    Returns:
    --------
    [helm.HelmRelease]
        Generated HelmRelease resource

    Example XR:
    -----------
    apiVersion: example.io/v1alpha1
    kind: FluxHelmRelease
    spec:
      name: nginx
      chartName: nginx
      chartVersion: "15.0.0"
      sourceKind: HelmRepository
      sourceName: bitnami
      targetNamespace: production
      values:
        replicaCount: 3
    """
    # Get XR spec fields with Crossplane-compliant pattern
    configName = option("params")?.oxr?.spec?.name or "default-helmrelease"
    namespace = option("params")?.oxr?.spec?.namespace or "flux-system"
    chartName = option("params")?.oxr?.spec?.chartName or "chart"
    chartVersion = option("params")?.oxr?.spec?.chartVersion
    sourceKind = option("params")?.oxr?.spec?.sourceKind or "HelmRepository"
    sourceName = option("params")?.oxr?.spec?.sourceName or "default-source"
    sourceNamespace = option("params")?.oxr?.spec?.sourceNamespace
    interval = option("params")?.oxr?.spec?.interval or "5m"
    values = option("params")?.oxr?.spec?.values or {}
    targetNamespace = option("params")?.oxr?.spec?.targetNamespace
    releaseName = option("params")?.oxr?.spec?.releaseName or configName

    # Boolean handling with explicit False checking
    _createNamespaceValue = option("params")?.oxr?.spec?.createNamespace
    createNamespace = False if _createNamespaceValue == False else True

    _suspendValue = option("params")?.oxr?.spec?.suspend
    suspend = False if _suspendValue == False else True

    # Generate HelmRelease
    generateHelmRelease(SimpleHelmRelease {
        name = configName
        namespace = namespace
        chart = ChartRef {
            name = chartName
            version = chartVersion
            sourceRef = SourceRef {
                kind = sourceKind
                name = sourceName
                namespace = sourceNamespace
            }
        }
        interval = interval
        values = values
        targetNamespace = targetNamespace
        releaseName = releaseName
        suspend = suspend
        install = InstallConfig {
            createNamespace = createNamespace
        }
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "flux-helmrelease-{}".format(configName)
        }
    })
}

# Default export for Crossplane usage
items = generateCrossplaneHelmRelease()
