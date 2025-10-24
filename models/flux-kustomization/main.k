"""The_first_kcl_program = 'Hello World!'
Flux Kustomization KCL Module

This module provides simplified schemas and helper functions for creating
Flux Kustomization resources using the generated CRD models.

Generated from: https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/kustomize-controller.yaml
CRD Version: Flux v2.7.2
Conversion Date: 2025-10-23
"""

import v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm

# --- Simplified Schemas ---

schema SimpleKustomization:
    """
    Simplified Flux Kustomization configuration with sensible defaults.

    Attributes:
    -----------
    name: str
        Name of the Kustomization resource
    namespace: str
        Namespace where the Kustomization will be created (default: flux-system)
    path: str
        Path to the directory containing kustomization.yaml or plain YAMLs (default: ./)
    sourceRef: SourceRef
        Reference to the source (GitRepository, OCIRepository, Bucket)
    interval: str
        Reconciliation interval (default: 5m)
    prune: bool
        Enable garbage collection (default: True)
    targetNamespace: str
        Target namespace for deployed resources
    dependsOn: [DependencyRef]
        List of Kustomizations that must be ready first
    healthChecks: [HealthCheck]
        Resources to include in health assessment
    postBuild: PostBuild
        PostBuild configuration for substitutions
    """
    name: str
    namespace?: str = "flux-system"
    path?: str = "./"
    sourceRef: SourceRef
    interval?: str = "1h"           # Default: 1h
    retryInterval?: str = "1m"      # Default: 1m
    timeout?: str = "5m"            # Default: 5m
    prune?: bool = True              # Default: true
    wait?: bool = True               # Default: true
    targetNamespace?: str
    dependsOn?: [DependencyRef]
    healthChecks?: [HealthCheck]
    postBuild?: PostBuild
    force?: bool = False
    suspend?: bool = False
    labels?: {str: str}
    annotations?: {str: str}

schema SourceRef:
    """
    Reference to a Flux Source resource.

    Attributes:
    -----------
    kind: str
        Source kind (GitRepository, OCIRepository, Bucket)
    name: str
        Name of the source
    namespace: str
        Namespace of the source (optional, defaults to same as Kustomization)
    """
    kind: "GitRepository" | "OCIRepository" | "Bucket"
    name: str
    namespace?: str

schema DependencyRef:
    """
    Reference to another Kustomization that must be ready first.

    Attributes:
    -----------
    name: str
        Name of the Kustomization to depend on
    namespace: str
        Namespace of the dependency (optional)
    """
    name: str
    namespace?: str

schema HealthCheck:
    """
    Resource to include in health assessment.

    Attributes:
    -----------
    apiVersion: str
        API version of the resource
    kind: str
        Kind of the resource
    name: str
        Name of the resource (optional, for specific resource)
    namespace: str
        Namespace of the resource
    """
    apiVersion: str
    kind: str
    name?: str
    namespace?: str

schema PostBuild:
    """
    PostBuild configuration for variable substitution.

    Attributes:
    -----------
    substitute: {str: str}
        Key-value pairs for variable substitution
    substituteFrom: [SubstituteReference]
        ConfigMaps/Secrets to use for substitution
    """
    substitute?: {str: str}
    substituteFrom?: [SubstituteReference]

schema SubstituteReference:
    """
    Reference to ConfigMap or Secret for variable substitution.

    Attributes:
    -----------
    kind: str
        ConfigMap or Secret
    name: str
        Name of the ConfigMap/Secret
    optional: bool
        Whether the reference is optional
    """
    kind: "ConfigMap" | "Secret"
    name: str
    optional?: bool = False

# --- Helper Functions ---

generateKustomization = lambda config: SimpleKustomization -> [flux.Kustomization] {
    """
    Generate a Flux Kustomization from simplified configuration.

    Parameters:
    -----------
    config: SimpleKustomization
        Simplified Kustomization configuration

    Returns:
    --------
    [flux.Kustomization]
        List containing the generated Kustomization resource

    Example:
    --------
    myKustomization = generateKustomization(SimpleKustomization {
        name = "my-app"
        sourceRef = SourceRef {
            kind = "GitRepository"
            name = "my-repo"
        }
        path = "./deploy/production"
    })
    """
    [
        flux.Kustomization {
            apiVersion = "kustomize.toolkit.fluxcd.io/v1"
            kind = "Kustomization"
            metadata = {
                name = config.name
                namespace = config.namespace or "flux-system"
                labels = config.labels or {}
                annotations = config.annotations or {}
            }
            spec = {
                interval = config.interval or "5m"
                path = config.path or "./"
                prune = config.prune if config.prune != None else True
                # Make sourceRef access nil-safe. If config.sourceRef is missing
                # provide sensible defaults to avoid runtime errors.
                sourceRef = {
                    kind = config.sourceRef?.kind or "GitRepository"
                    name = config.sourceRef?.name or "flux-apps"
                    namespace = config.sourceRef?.namespace
                }
                targetNamespace = config.targetNamespace
                dependsOn = [
                    {
                        name = dep.name
                        namespace = dep.namespace
                    } if dep.namespace else {
                        name = dep.name
                    }
                    for dep in config.dependsOn
                ] if config.dependsOn else []
                healthChecks = [
                    {
                        apiVersion = hc.apiVersion
                        kind = hc.kind
                        namespace = hc.namespace
                    } if not hc.name else {
                        apiVersion = hc.apiVersion
                        kind = hc.kind
                        name = hc.name
                        namespace = hc.namespace
                    }
                    for hc in config.healthChecks
                ] if config.healthChecks else []
                # Emit postBuild and merge defaults per-key so YAML can override.
                postBuild = {
                    substitute = {
                        "TEKTON_NAMESPACE" = config.postBuild?.substitute?.TEKTON_NAMESPACE or "tekton-pipelines"
                        "TEKTON_VERSION" = config.postBuild?.substitute?.TEKTON_VERSION or "0.76.1"
                    }
                    substituteFrom = [
                        {
                            kind = ref.kind
                            name = ref.name
                            optional = ref.optional if ref.optional != None else False
                        }
                        for ref in (config.postBuild?.substituteFrom or [])
                    ]
                }
                force = config.force if config.force != None else False
                wait = config.wait if config.wait != None else False
                timeout = config.timeout or "5m"
                retryInterval = config.retryInterval or "2m"
                suspend = config.suspend if config.suspend != None else False
            }
        }
    ]
}

# --- Convenience Functions ---

gitKustomization = lambda name: str, gitRepoName: str, path: str = "./" -> [flux.Kustomization] {
    """
    Quick helper to create a Kustomization from a GitRepository source.

    Parameters:
    -----------
    name: str
        Name of the Kustomization
    gitRepoName: str
        Name of the GitRepository source
    path: str
        Path in the repository (default: ./)

    Returns:
    --------
    [flux.Kustomization]
        Generated Kustomization resource

    Example:
    --------
    app = gitKustomization("my-app", "my-repo", "./apps/production")
    """
    generateKustomization(SimpleKustomization {
        name = name
        sourceRef = SourceRef {
            kind = "GitRepository"
            name = gitRepoName
        }
        path = path
    })
}

ociKustomization = lambda name: str, ociRepoName: str, path: str = "./" -> [flux.Kustomization] {
    """
    Quick helper to create a Kustomization from an OCIRepository source.

    Parameters:
    -----------
    name: str
        Name of the Kustomization
    ociRepoName: str
        Name of the OCIRepository source
    path: str
        Path in the OCI artifact (default: ./)

    Returns:
    --------
    [flux.Kustomization]
        Generated Kustomization resource

    Example:
    --------
    app = ociKustomization("my-app", "my-oci-repo", "./manifests")
    """
    generateKustomization(SimpleKustomization {
        name = name
        sourceRef = SourceRef {
            kind = "OCIRepository"
            name = ociRepoName
        }
        path = path
    })
}

# --- Crossplane XR Helper ---

generateCrossplaneKustomization = lambda -> any {
    """
    Generate Kustomization from Crossplane XR spec using standard variable pattern.

    Expects XR spec fields:
    - name: str (Kustomization name)
    - namespace: str (optional, default: flux-system)
    - path: str (optional, default: ./)
    - sourceKind: str (GitRepository, OCIRepository, Bucket)
    - sourceName: str
    - sourceNamespace: str (optional)
    - interval: str (optional, default: 5m)
    - prune: bool (optional, default: true)
    - targetNamespace: str (optional)

    Returns:
    --------
    [flux.Kustomization]
        Generated Kustomization resource

    Example XR:
    -----------
    apiVersion: example.io/v1alpha1
    kind: FluxKustomization
    spec:
      name: my-app
      sourceKind: GitRepository
      sourceName: my-repo
      path: ./deploy
      targetNamespace: production
    """
    # Get XR spec fields with flexible param shapes. Support:
    # - params: { oxr: { spec: { ... } } }
    # - params: { spec: { ... } }
    # - params: { ... } (direct spec fields)
    p = option("params")
    spec = p?.oxr?.spec or p?.spec or p or {}

    configName = spec?.name or "default-kustomization"
    namespace = spec?.namespace or "flux-system"
    path = spec?.path or "./"
    sourceKind = spec?.sourceKind or "GitRepository"
    sourceName = spec?.sourceName or "flux-apps"
    sourceNamespace = spec?.sourceNamespace
    interval = spec?.interval or "1h"
    retryInterval = spec?.retryInterval or "1m"
    timeout = spec?.timeout or "5m"
    targetNamespace = spec?.targetNamespace

    # Boolean handling with explicit False checking
    _pruneValue = spec?.prune
    prune = True if _pruneValue == None else _pruneValue

    _waitValue = spec?.wait
    wait = True if _waitValue == None else _waitValue

    _forceValue = spec?.force
    force = False if _forceValue == False else True

    _suspendValue = spec?.suspend
    suspend = False if _suspendValue == False else True

    # Construct a plain mapping to avoid deeper validation that may error on missing
    # internal fields when running from different working directories. This mapping
    # mirrors the Kustomization CRD structure and is safe to emit directly.
    # Emit postBuild substitutions with per-key fallback so spec values override defaults
    {
        apiVersion = "kustomize.toolkit.fluxcd.io/v1"
        kind = "Kustomization"
        metadata = {
            name = configName
            namespace = namespace
            labels = {}
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "flux-kustomization-{}".format(configName)
            }
        }
        spec = {
            interval = interval
            retryInterval = retryInterval
            timeout = timeout
            path = path
            prune = prune
            wait = wait
            sourceRef = {
                kind = sourceKind
                name = sourceName
                namespace = sourceNamespace
            }
            targetNamespace = targetNamespace
            force = force
            suspend = suspend
            postBuild = {
                substitute = {
                    "TEKTON_NAMESPACE" = spec?.postBuild?.substitute?.TEKTON_NAMESPACE or "tekton-pipelines"
                    "TEKTON_VERSION" = spec?.postBuild?.substitute?.TEKTON_VERSION or "0.76.1"
                }
                substituteFrom = spec?.postBuild?.substituteFrom or []
            }
        }
    }
}

# Default export for Crossplane usage
items = generateCrossplaneKustomization()
