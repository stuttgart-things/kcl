"""
Pure logic for the platform Configuration — no option("params"), so every rule
here is unit-testable with `kcl test`. main.k is the thin render entry point.

The reason this module exists: stuttgart-things/flux publishes ONE OCI ARTIFACT
PER APP, so a Flux source name and an app are the same fact. Enabling an app
therefore has to produce BOTH an OCIRepository source (on the FluxInit child)
and a Kustomization entry (on the FluxApps child). Keeping those two in sync by
hand is the error this module removes.
"""

import xplane_flux_catalog as cat

resolveShared = lambda spec: {str:} -> {str:} {
    """The shared cluster contract, resolved once and handed to every component.

    clusterName derives {clusterName}-helm / {clusterName}-kubernetes — the names
    provider-kubeconfig's RemoteCluster creates. Explicit refs always win.
    Unresolved fields are OMITTED, never emitted as "", so a consumer can test
    `if shared.clusterType` and trust it.
    """
    _cn = spec?.clusterName or ""
    {
        if _cn:
            clusterName = _cn
        helmProviderConfigRef = spec?.helmProviderConfigRef or ("{}-helm".format(_cn) if _cn else "")
        kubernetesProviderConfigRef = spec?.kubernetesProviderConfigRef or ("{}-kubernetes".format(_cn) if _cn else "")
        observeProviderConfigRef = spec?.observeProviderConfigRef or "in-cluster"
        namespace = spec?.namespace or "flux-system"
    }
}

isEnabled = lambda block: {str:} -> bool {
    """`or True` would swallow an explicit false, so test for the key."""
    block.enabled if "enabled" in block else True
}

compEnabled = lambda comp: any, override: {str:} -> bool {
    """A component's enablement. Catalog `optional` components are opt-in: they
    are not deployed unless the XR names them, because they ship variables the
    base app does not need (cert-manager's selfsigned issuer wants a domain)."""
    override.enabled if "enabled" in override else not comp.optional
}

enabledApps = lambda spec: {str:} -> {str:} {
    """spec.apps entries that are enabled. Map, not list, so overrides merge."""
    {k: v for k, v in (spec?.apps or {}) if isEnabled(v or {})}
}

fluxInitEnabled = lambda spec: {str:} -> bool {
    isEnabled(spec?.fluxInit or {})
}

depApp = lambda owner: str, dep: str -> str {
    """Owning app of a dependsOn reference. "cert-manager:install" is
    cross-artifact; a bare name is a sibling in the same app."""
    dep.split(":")[0] if ":" in dep else owner
}

depComponent = lambda dep: str -> str {
    dep.split(":")[1] if ":" in dep else dep
}

depName = lambda owner: str, dep: str -> str {
    """The emitted Kustomization name — globally unique, since app names are."""
    depApp(owner, dep) + "-" + depComponent(dep)
}

appSources = lambda spec: {str:} -> [{str:}] {
    """OCIRepository sources for the FluxInit child — one per enabled app.

    The source is named after the app, which is what lets appEntries() reference
    it without the user restating the name.
    """
    [{
        name = _n
        kind = "OCIRepository"
        url = cat.get(_n).artifact
        ref = (_a?.version or cat.get(_n).defaultVersion)
    } for _n, _a in enabledApps(spec)]
}

appEntries = lambda spec: {str:} -> [{str:}] {
    """FluxApps `apps[]` entries — one per enabled component of each enabled app.

    An app is not necessarily one Kustomization (dapr ships control-plane +
    template-execution), so components are expanded here and dependsOn is
    rewritten to the emitted '{app}-{component}' names.
    """
    sum([[{
        name = "{}-{}".format(_n, _c.name)
        path = _c.path
        sourceRef = {kind = "OCIRepository", name = _n}
        if _c.dependsOn:
            dependsOn = [{name = depName(_n, _d)} for _d in _c.dependsOn]
        if (((_a?.components or {})[_c.name] or {})?.timeout or _c.timeout):
            timeout = ((_a?.components or {})[_c.name] or {})?.timeout or _c.timeout
        if (_a?.substitute or {}) | (((_a?.components or {})[_c.name] or {})?.substitute or {}):
            substitute = (_a?.substitute or {}) | (((_a?.components or {})[_c.name] or {})?.substitute or {})
        if ((_a?.components or {})[_c.name] or {})?.substituteFrom:
            substituteFrom = ((_a?.components or {})[_c.name] or {}).substituteFrom
        if (((_a?.components or {})[_c.name] or {})?.targetNamespace or _a?.targetNamespace):
            targetNamespace = ((_a?.components or {})[_c.name] or {})?.targetNamespace or _a?.targetNamespace
    } for _c in cat.get(_n).components if compEnabled(_c, (_a?.components or {})[_c.name] or {})] for _n, _a in enabledApps(spec)], [])
}

_compOverride = lambda app: {str:}, name: str -> {str:} {
    (app?.components or {})[name] or {}
}

_appMissing = lambda name: str, app: {str:} -> [str] {
    """Required vars of one app that nothing supplies. A component carrying
    substituteFrom is skipped — its values come from a ConfigMap/Secret resolved
    at build time, which cannot be checked statically."""
    _supplied = lambda cname: str -> {str:} {
        (app?.substitute or {}) | (_compOverride(app, cname)?.substitute or {})
    }
    _checked = [c for c in cat.get(name).components if compEnabled(c, _compOverride(app, c.name)) and not _compOverride(app, c.name)?.substituteFrom]
    sum([[name + "-" + c.name + ": " + v for v in c.requiredSubstitutions if v not in _supplied(c.name)] for c in _checked], [])
}

missingSubstitutions = lambda spec: {str:} -> [str] {
    """Required substitution variables that nothing supplies.

    Flux replaces an undefined variable with an empty string instead of failing,
    so a missing one is a silently broken deploy — that is what this catches.
    """
    sum([_appMissing(n, a) for n, a in enabledApps(spec)], [])
}

_compEnabled = lambda apps: {str:}, appName: str, compName: str -> bool {
    """Is a (possibly cross-app) component enabled in this XR?"""
    _match = [c for c in cat.get(appName).components if c.name == compName]
    len(_match) > 0 and compEnabled(_match[0], ((apps[appName] or {})?.components or {})[compName] or {})
}

appDepProblems = lambda name: str, app: {str:}, apps: {str:} -> [str] {
    """Dependencies of one app that cannot be satisfied by this XR.

    Deliberately rejects rather than auto-enabling the missing app: a toggle that
    silently installs artifacts you did not list gets confusing with transitive
    chains, and it conflicts with disable-prunes. The message names what to add.
    """
    _checked = [c for c in cat.get(name).components if compEnabled(c, _compOverride(app, c.name))]
    _pairs = sum([[{owner = c.name, dep = d} for d in c.dependsOn] for c in _checked], [])
    _noApp = [name + "-" + p.owner + " depends on " + p.dep + ", but app '" + depApp(name, p.dep) + "' is not enabled — add it to spec.apps" for p in _pairs if depApp(name, p.dep) not in apps]
    _offComp = [name + "-" + p.owner + " depends on " + p.dep + ", but component '" + depComponent(p.dep) + "' of app '" + depApp(name, p.dep) + "' is disabled — enable it or drop the dependency" for p in _pairs if depApp(name, p.dep) in apps and not _compEnabled(apps, depApp(name, p.dep), depComponent(p.dep))]
    _noApp + _offComp
}

depProblems = lambda spec: {str:} -> [str] {
    """Every unsatisfiable dependency in this XR, as human-readable messages."""
    _apps = enabledApps(spec)
    sum([appDepProblems(_n, _a, _apps) for _n, _a in _apps], [])
}

validate = lambda spec: {str:} -> bool {
    """Rules that must hold before anything is emitted.

    The fluxInit rule is also a CEL rule on the XRD (which fails at apply time,
    a much better signal); it is repeated here so the module is safe for any
    caller, not only that XRD.
    """
    _apps = enabledApps(spec)
    assert fluxInitEnabled(spec) or len(_apps) == 0, "apps are enabled but fluxInit is disabled — fluxInit creates the Flux sources every app references; enable fluxInit or disable all apps"

    # An unsatisfiable dependency would sit in DependencyNotReady forever; fail at
    # render instead, naming what to add. Covers cross-artifact references
    # ("cert-manager:install") as well as siblings.
    # KCL does NOT interpolate ${} inside assert messages — it prints the
    # placeholder literally — so the messages are concatenated.
    _depProblems = depProblems(spec)
    assert len(_depProblems) == 0, "unsatisfiable dependencies — " + "; ".join(_depProblems)
    _missing = missingSubstitutions(spec)
    assert len(_missing) == 0, "required substitution variables are not supplied (Flux substitutes empty strings rather than failing, so this would deploy silently broken): " + ", ".join(_missing)
    True
}
