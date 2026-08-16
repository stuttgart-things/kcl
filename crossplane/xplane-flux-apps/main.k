"""
xplane-flux-apps — function-kcl module for the flux-apps Crossplane Configuration.

Generic app deployment for Flux: given a namespaced `FluxApps` XR that lists
apps, this module emits one `kubernetes.m.crossplane.io/v1alpha1` Object per
app, each wrapping a `kustomize.toolkit.fluxcd.io/v1` Kustomization applied to a
target cluster. It is the data-driven generalization of the
`flux-app-kustomizations` KCL module: the hardcoded tekton/crossplane
Kustomizations there become entries in `spec.apps` here.

Each Kustomization references an existing Flux source (GitRepository /
OCIRepository / Bucket) — the source itself is a precondition on the target
cluster (typically bootstrapped by the `flux-init` Configuration).

Render and status are done in a single pass: the module emits the managed
resources AND patches the XR status from `ocds` (observed composed resources).
On the first reconcile `ocds` is empty, so `status.ready` starts False and
converges as the composed Kustomizations become Ready.

Defaults resolve spec > `flux-apps-defaults` EnvironmentConfig > hardcoded
fallback (surfaced by the composition's function-environment-configs step under
`params.ctx["apiextensions.crossplane.io/environment"]`).
"""

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}
_env = (_params?.ctx or {})["apiextensions.crossplane.io/environment"] or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}
_name = _meta?.name or "flux-apps"

# --- Provider config ref (required by the XRD) ---
_k8sPcr = _spec?.kubernetesProviderConfigRef

# --- Resolve shared defaults: spec > EnvironmentConfig > hardcoded fallback ---
_ns = _spec?.namespace or _env?.namespace or "flux-system"
_interval = _spec?.interval or _env?.interval or "1h"
_retryInterval = _spec?.retryInterval or _env?.retryInterval or "1m"
_timeout = _spec?.timeout or _env?.timeout or "5m"
_prune = _spec.prune if "prune" in _spec else True
_wait = _spec.wait if "wait" in _spec else True

# Default source referenced by every app (per-app spec.apps[].sourceRef wins).
_sourceRef = _spec?.sourceRef or _env?.sourceRef or {}
_srcKind = _sourceRef?.kind or "GitRepository"
_srcName = _sourceRef?.name or "flux-apps"
_srcNs = _sourceRef?.namespace or ""

# Common metadata applied to all apps unless overridden per-app.
_commonMeta = _spec?.commonMetadata or {}

_apps = _spec?.apps or []

# --- ocds key / composition-resource-name for an app ---
_appResName = lambda app: {str:} -> str {
    "{}-app-{}".format(_name, app.name)
}

# --- Build one provider-kubernetes Object wrapping a Flux Kustomization ---
_appObject = lambda app: {str:} -> {str:} {
    _resName = _appResName(app)
    _src = app?.sourceRef or {}
    _sourceRefOut = {
        kind = _src?.kind or _srcKind
        name = _src?.name or _srcName
        **({namespace = _src.namespace} if _src?.namespace else ({namespace = _srcNs} if _srcNs else {}))
    }
    _sub = app?.substitute or {}
    _subFrom = app?.substituteFrom or []

    # ALWAYS EMITTED AND NEVER EMPTY. Both halves are load-bearing, and the
    # second was learned the hard way twice.
    #
    # kustomize-controller skips its variable-substitution pass unless there is
    # something to substitute, so an app with no substitute block gets NO
    # substitution — and every `${VAR:-default}` fallback in its manifests
    # silently stops being a fallback. What reaches the cluster is the literal
    # string:
    #
    #   Namespace/${OPENEBS_NAMESPACE:-openebs} dry-run failed (Invalid):
    #   metadata.name: Invalid value: "${OPENEBS_NAMESPACE:-openebs}"
    #
    # 0.2.0 fixed the first half — postBuild is emitted unconditionally — on the
    # belief that `PostBuild != nil` was the whole condition upstream. IT IS
    # NOT. Measured on u26-rke2-1, 2026-08-16, with before/after on a running
    # cluster: with `substitute: {}` the Kustomization stayed
    # ReconciliationFailed on exactly that error, through a forced reconcile;
    # adding one real entry made it Ready. It bit openebs first and
    # external-secrets second, so it is not one app's quirk — it is every app
    # enabled bare, which is the case the catalog advertises as the easy one.
    #
    # Hence the marker: one inert entry, whose only job is to be non-empty. It
    # names its author so nobody deletes it as noise. A user-supplied key of the
    # same name would win, which is harmless.
    #
    # NO LEADING UNDERSCORE in the key. KCL treats an underscore-prefixed
    # attribute as private and drops it from the emitted output — a marker named
    # `_XPLANE_FLUX_APPS` renders as `substitute: {}`, i.e. exactly the bug it
    # exists to prevent, and silently.
    _marker = {XPLANE_FLUX_APPS = "substitution-marker"}
    _postBuild = {
        substitute = _marker | _sub
        **({substituteFrom = _subFrom} if _subFrom else {})
    }
    _appCommon = app?.commonMetadata or _commonMeta
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = _resName
            namespace = _ns
            annotations = {
                "krm.kcl.dev/composition-resource-name" = _resName
            }
        }
        spec = {
            providerConfigRef = {
                name = _k8sPcr
                kind = "ClusterProviderConfig"
            }
            forProvider = {
                manifest = {
                    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
                    kind = "Kustomization"
                    metadata = {
                        name = app.name
                        namespace = _ns
                    }
                    spec = {
                        interval = app?.interval or _interval
                        retryInterval = app?.retryInterval or _retryInterval
                        timeout = app?.timeout or _timeout
                        sourceRef = _sourceRefOut
                        path = app.path
                        prune = app.prune if "prune" in app else _prune
                        wait = app.wait if "wait" in app else _wait
                        **({force = app.force} if "force" in app else {})
                        **({targetNamespace = app.targetNamespace} if app?.targetNamespace else {})
                        **({dependsOn = app.dependsOn} if app?.dependsOn else {})
                        **({components = app.components} if app?.components else {})
                        **({commonMetadata = _appCommon} if _appCommon else {})
                        **({healthChecks = app.healthChecks} if app?.healthChecks else {})
                        **({healthCheckExprs = app.healthCheckExprs} if app?.healthCheckExprs else {})
                        **({patches = app.patches} if app?.patches else {})
                        **({images = app.images} if app?.images else {})
                        **({decryption = app.decryption} if app?.decryption else {})
                        # Unconditional AND never empty, deliberately — see
                        # _postBuild above.
                        postBuild = _postBuild
                    }
                }
            }
            readiness = {
                policy = "DeriveFromObject"
            }
        }
    }
}

_appObjects = [_appObject(a) for a in _apps]

# --- Status: read Ready condition off each composed resource via ocds ---
_isReady = lambda resourceName: str -> bool {
    _found = resourceName in _ocds
    _conds = _ocds[resourceName]?.Resource?.status?.conditions or [] if _found else []
    len([c for c in _conds if c.type == "Ready" and c.status == "True"]) > 0
}

_readyApps = [a.name for a in _apps if _isReady(_appResName(a))]
_appsReady = len(_readyApps) == len(_apps) if _apps else True

_xrStatus = _oxr | {
    status = {
        appsReady = _appsReady
        ready = _appsReady
        appCount = len(_apps)
        readyCount = len(_readyApps)
    }
}

items = _appObjects + [_xrStatus]
