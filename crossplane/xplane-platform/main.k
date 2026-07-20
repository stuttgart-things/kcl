"""
xplane-platform — function-kcl module for the platform Crossplane Configuration.

Composes one child XR per enabled component of a cluster's platform:
  0. Cni       (cni Configuration)        — cluster networking; opt-in, and the
     other children are gated on it, because a cluster with no CNI has NotReady
     nodes and a Helm install aimed at it times out rather than failing fast
  1. FluxInit  (flux-init Configuration)  — Flux itself, plus one OCIRepository
     source per enabled app
  2. FluxApps  (flux-apps Configuration)  — one Kustomization per enabled
     component of each enabled app

Render and status happen in a single pass: the module emits the child XRs AND
patches the XR status from `ocds`. On the first reconcile `ocds` is empty, so
status.ready starts False and converges as the children become Ready.

All decision logic lives in logic.k so it is unit-testable without Crossplane;
this file only marshals option("params") in and `items` out.
"""

import .logic as l

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}
_name = _meta?.name or "platform"
_namespace = _meta?.namespace or "default"

_valid = l.validate(_spec)
_shared = l.resolveShared(_spec)

_fluxEnabled = l.fluxInitEnabled(_spec)
_apps = l.enabledApps(_spec)
_appsEnabled = len(_apps) > 0
_cniEnabled = l.cniEnabled(_spec)

_cniKey = "{}-cni".format(_name)
_fluxKey = "{}-flux-init".format(_name)
_appsKey = "{}-flux-apps".format(_name)

# --- Read child status back (needed by the CNI gate below, so defined early) ---
_readStatus = lambda key: str -> {str:} {
    (_ocds[key].Resource?.status or {}) if key in _ocds else {}
}
_isReady = lambda st: {str:} -> bool {
    len([c for c in (st?.conditions or []) if c.type == "Ready" and c.status == "True"]) > 0
}

# --- Child 0: Cni ---
# Not just another component: until it is Ready the target cluster's nodes are
# NotReady, so nothing schedules — and a Helm install aimed at such a cluster
# does not fail fast, it times out and retries. So the other children are held
# until this one reports ready.
_cniSpec = _spec?.cni or {}
_cniStatus = _readStatus(_cniKey)
_cniReady = _isReady(_cniStatus)

_cniXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "Cni"
    metadata = {
        name = _cniKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _cniKey}
    }
    spec = {
        if _shared?.clusterName:
            clusterName = _shared.clusterName
        if _shared.helmProviderConfigRef:
            helmProviderConfigRef = _shared.helmProviderConfigRef
        observeProviderConfigRef = _shared.observeProviderConfigRef
        if _cniSpec?.provider:
            provider = _cniSpec.provider
        # NOT _shared.namespace: that is the Flux namespace. A CNI belongs in
        # kube-system, which the cni Configuration defaults to on its own.
        if _cniSpec?.namespace:
            namespace = _cniSpec.namespace
        if _cniSpec?.chart:
            chart = _cniSpec.chart
        if _cniSpec?.cilium:
            cilium = _cniSpec.cilium
        if _cniSpec?.values:
            values = _cniSpec.values
    }
}

# One-way gate: once a child exists, keep emitting it even if the CNI blips
# not-Ready during a chart upgrade — otherwise Crossplane would delete it.
_networkReady = _cniReady if _cniEnabled else True

# --- Child 1: FluxInit ---
# Sources are the union of what the XR declared and what enabling an app
# implies. The app-derived ones are what make `apps: {dapr: {}}` sufficient.
_fluxSpec = _spec?.fluxInit or {}
_declaredSources = ((_fluxSpec?.instance or {})?.sources or [])
_allSources = _declaredSources + l.appSources(_spec)

_fluxInitXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "FluxInit"
    metadata = {
        name = _fluxKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _fluxKey}
    }
    spec = {
        if _shared?.clusterName:
            clusterName = _shared.clusterName
        if _shared.helmProviderConfigRef:
            helmProviderConfigRef = _shared.helmProviderConfigRef
        if _shared.kubernetesProviderConfigRef:
            kubernetesProviderConfigRef = _shared.kubernetesProviderConfigRef
        observeProviderConfigRef = _shared.observeProviderConfigRef
        namespace = _shared.namespace
        if _fluxSpec?.operatorChart:
            operatorChart = _fluxSpec.operatorChart
        if (_fluxSpec?.instance or _allSources):
            instance = (_fluxSpec?.instance or {}) | ({sources = _allSources} if _allSources else {})
        if _fluxSpec?.kustomize:
            kustomize = _fluxSpec.kustomize
        if _fluxSpec?.sops:
            sops = _fluxSpec.sops
    }
}

# --- Child 2: FluxApps ---
# Only the kubernetes ref is projected: flux-apps takes no clusterName and no
# helm ref, so the shared contract is applied per component, not forwarded whole.
_fluxAppsXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "FluxApps"
    metadata = {
        name = _appsKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _appsKey}
    }
    spec = {
        kubernetesProviderConfigRef = _shared.kubernetesProviderConfigRef
        namespace = _shared.namespace
        apps = l.appEntries(_spec)
    }
}

_children = ([_cniXR] if _cniEnabled else []) + ([_fluxInitXR] if (_fluxEnabled and l.gateOpen(_networkReady, _fluxKey in _ocds)) else []) + ([_fluxAppsXR] if (_appsEnabled and l.gateOpen(_networkReady, _appsKey in _ocds)) else [])

_fluxStatus = _readStatus(_fluxKey)
_fluxReady = _isReady(_fluxStatus)
_appsStatus = _readStatus(_appsKey)
_appsReady = _isReady(_appsStatus)

# clusterType is discovered by the FluxInit child from the RemoteCluster; lifting
# it into shared status keeps later components from re-observing it.
_clusterType = _fluxStatus?.clusterType or ""

_enabledReady = ([_cniReady] if _cniEnabled else []) + ([_fluxReady] if _fluxEnabled else []) + ([_appsReady] if _appsEnabled else [])
_readyComponents = len([r for r in _enabledReady if r])

_xrStatus = _oxr | {
    status = {
        shared = _shared | ({clusterType = _clusterType} if _clusterType else {})
        components = {
            cni = {
                enabled = _cniEnabled
                ready = _cniReady
                provider = _cniStatus?.provider or ""
                version = _cniStatus?.version or ""
            }
            fluxInit = {
                enabled = _fluxEnabled
                ready = _fluxReady
                operatorReady = _fluxStatus?.operatorReady or False
                instanceReady = _fluxStatus?.instanceReady or False
                sourcesReady = _fluxStatus?.sourcesReady or False
                sourceCount = _fluxStatus?.sourceCount or 0
            }
            fluxApps = {
                enabled = _appsEnabled
                ready = _appsReady
                appCount = _appsStatus?.appCount or 0
                readyCount = _appsStatus?.readyCount or 0
            }
        }
        componentCount = len(_enabledReady)
        readyComponents = _readyComponents
        # Vacuously true with nothing enabled — matches what function-auto-ready
        # reports on the Ready condition when there is nothing to wait for.
        ready = _readyComponents == len(_enabledReady)
    }
}

items = _children + [_xrStatus]
