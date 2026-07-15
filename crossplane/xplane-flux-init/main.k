"""
xplane-flux-init — function-kcl module for the flux-init Crossplane Configuration.

Bootstraps Flux on a target cluster via the flux-operator:
  1. helm.m.crossplane.io Release  — flux-operator chart
  2. kubernetes.m.crossplane.io Object — FluxInstance CR (uses operator)
  3. protection.crossplane.io Usage — FluxInstance deletes before operator
  4. kubernetes.m.crossplane.io Object(s) — one OCIRepository/GitRepository per source

Render and status are done in a single pass: the module emits the managed
resources AND patches the XR status from `ocds` (observed composed resources).
On the first reconcile `ocds` is empty, so status.ready starts False and
converges as the composed resources become Ready.

Defaults come from the `flux-defaults` EnvironmentConfig, surfaced by the
composition's function-environment-configs step under
`params.ctx["apiextensions.crossplane.io/environment"]`. Per-XR spec fields
always win over the EnvironmentConfig, which in turn wins over the hardcoded
fallbacks below.
"""

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}
_env = (_params?.ctx or {})["apiextensions.crossplane.io/environment"] or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}
_name = _meta?.name or "flux-init"

# --- Provider config refs (required by the XRD) ---
_helmPcr = _spec?.helmProviderConfigRef
_k8sPcr = _spec?.kubernetesProviderConfigRef

# --- Resolve values: spec > EnvironmentConfig > hardcoded fallback ---
_ns = _spec?.namespace or _env?.namespace or "flux-system"
_version = _spec?.operatorChart?.version or _env?.operatorChart?.version or "0.45.1"
_repoURL = _spec?.operatorChart?.repoURL or _env?.operatorChart?.repoURL or "oci://ghcr.io/controlplaneio-fluxcd/charts"
_distribution = _spec?.instance?.distribution or _env?.instance?.distribution or "2.x"
_components = _spec?.instance?.components or _env?.instance?.components or [
    "source-controller"
    "kustomize-controller"
    "helm-controller"
    "notification-controller"
]
_sources = _spec?.instance?.sources or []
_reconcileEvery = _env?.reconcileEvery or "1h"
_reconcileTimeout = _env?.reconcileTimeout or "5m"

# --- Resource names (also the ocds keys used for status) ---
_operatorName = "{}-flux-operator".format(_name)
_instanceName = "{}-flux-instance".format(_name)

# --- Resource 1: HelmRelease (flux-operator) ---
_helmRelease = {
    apiVersion = "helm.m.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = _operatorName
        namespace = _ns
        annotations = {
            "krm.kcl.dev/composition-resource-name" = _operatorName
            "crossplane.io/external-name" = "flux-operator"
        }
    }
    spec = {
        providerConfigRef = {
            name = _helmPcr
            kind = "ClusterProviderConfig"
        }
        forProvider = {
            chart = {
                name = "flux-operator"
                repository = _repoURL
                version = _version
            }
            namespace = _ns
            values = {
                installCRDs = True
            }
        }
        rollbackLimit = 3
    }
}

# --- Resource 2: FluxInstance CR (Object) — depends on operator ---
_fluxInstance = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {
        name = _instanceName
        namespace = _ns
        annotations = {
            "krm.kcl.dev/composition-resource-name" = _instanceName
            "crossplane.io/uses" = _operatorName
        }
    }
    spec = {
        providerConfigRef = {
            name = _k8sPcr
            kind = "ClusterProviderConfig"
        }
        forProvider = {
            manifest = {
                apiVersion = "fluxcd.controlplane.io/v1"
                kind = "FluxInstance"
                metadata = {
                    name = "flux"
                    namespace = _ns
                    annotations = {
                        "fluxcd.controlplane.io/reconcileEvery" = _reconcileEvery
                        "fluxcd.controlplane.io/reconcileTimeout" = _reconcileTimeout
                    }
                }
                spec = {
                    distribution = {
                        version = _distribution
                        registry = "ghcr.io/fluxcd"
                    }
                    components = _components
                }
            }
        }
        readiness = {
            policy = "DeriveFromObject"
        }
    }
}

# --- Resource 3: Usage — FluxInstance must be deleted before the operator ---
_fluxInstanceUsage = {
    apiVersion = "protection.crossplane.io/v1beta1"
    kind = "Usage"
    metadata = {
        name = "{}-flux-instance-uses-operator".format(_name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "{}-flux-instance-uses-operator".format(_name)
        }
    }
    spec = {
        replayDeletion = True
        of = {
            apiVersion = "helm.m.crossplane.io/v1beta1"
            kind = "Release"
            resourceRef = {
                name = _operatorName
            }
        }
        by = {
            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
            kind = "Object"
            resourceRef = {
                name = _instanceName
            }
        }
    }
}

# --- Resources 4..N: source repositories (OCIRepository/GitRepository) ---
_sourceName = lambda s: {str:} -> str {
    "{}-source-{}".format(_name, s.name)
}
_sourceObjects = [
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = _sourceName(s)
            namespace = _ns
            annotations = {
                "krm.kcl.dev/composition-resource-name" = _sourceName(s)
                "crossplane.io/uses" = _instanceName
            }
        }
        spec = {
            providerConfigRef = {
                name = _k8sPcr
                kind = "ClusterProviderConfig"
            }
            forProvider = {
                manifest = {
                    apiVersion = "source.toolkit.fluxcd.io/v1"
                    kind = s?.kind or "OCIRepository"
                    metadata = {
                        name = s.name
                        namespace = _ns
                    }
                    spec = {
                        interval = _reconcileEvery
                        url = s.url
                        ref = {
                            tag = s?.ref or "latest"
                        }
                        **({secretRef = {name = s.pullSecret}} if s?.pullSecret else {})
                    }
                }
            }
            readiness = {
                policy = "DeriveFromObject"
            }
        }
    }
    for s in _sources
]

# --- Status: read Ready condition off each composed resource via ocds ---
_isReady = lambda resourceName: str -> bool {
    _found = resourceName in _ocds
    _conds = _ocds[resourceName]?.Resource?.status?.conditions or [] if _found else []
    len([c for c in _conds if c.type == "Ready" and c.status == "True"]) > 0
}

_operatorReady = _isReady(_operatorName)
_instanceReady = _isReady(_instanceName)
_readySources = [s.name for s in _sources if _isReady(_sourceName(s))]
_sourcesReady = len(_readySources) == len(_sources) if _sources else True

_xrStatus = _oxr | {
    status = {
        operatorReady = _operatorReady
        instanceReady = _instanceReady
        sourcesReady = _sourcesReady
        ready = _operatorReady and _instanceReady and _sourcesReady
        sourceCount = len(_sources)
    }
}

items = [_helmRelease, _fluxInstance, _fluxInstanceUsage] + _sourceObjects + [_xrStatus]
