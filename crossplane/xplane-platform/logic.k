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
import xplane_flux_catalog.schema as cs

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

cniEnabled = lambda spec: {str:} -> bool {
    """Opt-IN, unlike every other component.

    Most clusters already have a CNI and installing a second one breaks them, so
    the default has to be off — the inverse of fluxInit. Only clusters built
    deliberately blank (this fleet's ansible-provisioned kind clusters) enable it.
    """
    (spec?.cni or {})?.enabled or False
}

ciliumEnabled = lambda spec: {str:} -> bool {
    """Opt-IN. The cilium Configuration adds Cilium LoadBalancer + Gateway on top
    of the CNI (a superset of `cni`). Off by default — only clusters that want an
    advertised LB VIP / Gateway enable it. In the platform it defaults to
    install.enabled=false (the CNI is `cni`'s job or already on the cluster); it
    only layers the LB/Gateway services, so it is gated on the network being up."""
    (spec?.cilium or {})?.enabled or False
}

ipReservationEnabled = lambda spec: {str:} -> bool {
    """Opt-IN. Composes an XIPReservation (ip-reservation Configuration) that
    reserves a clusterbook IP for this cluster. Off by default. When both this and
    cilium (dynamic LB) are enabled, cilium's reservationRef auto-wires to this
    child so the reserved IP becomes the LB pool block."""
    (spec?.ipReservation or {})?.enabled or False
}

clusterDomain = lambda fqdn: str -> str {
    """The reservation's wildcard FQDN reduced to the name a consumer can use.

    clusterbook publishes `*.u26-rke2-1.sthings-vsphere.labul.sva.de` when
    createDNS is set — a wildcard record, so the leading `*.` is part of the DNS
    name, not of the domain. Everything downstream wants the remainder:
    CILIUM_GATEWAY_DOMAIN, a Gateway listener hostname, a certificate's common
    name. Stripping it once here is the point of publishing the value at all —
    the alternative is every consumer doing the same string surgery, which is
    the repetition this status field exists to remove.

    Anything that is not a wildcard is passed through untouched: an explicit
    `spec.ip` reservation carries no DNS name, and a future non-wildcard record
    would already be the usable form.
    """
    fqdn[2::] if fqdn.startswith("*.") else fqdn
}

vaultIssuerEnabled = lambda spec: {str:} -> bool {
    """Opt-IN. Provisions the TOKENLESS cert-manager -> Vault-PKI path: a Vault
    Kubernetes-auth mount (VaultK8sAuth), the CA bundle on the target
    (VaultPkiSecret), and the k8s-auth ClusterIssuer + TokenRequest RBAC. The
    cert-manager CONTROLLER itself comes via FluxApps (apps.cert-manager); this
    only wires the tokenless issuer on top. Prereqs (per cluster, on the mgmt
    cluster, in the Platform namespace): an AppRole tfvars secret + a reviewer
    backendConfig secret (target CA + reviewer JWT) + a source CA secret."""
    (spec?.vaultIssuer or {})?.enabled or False
}

certManagerReady = lambda ocds: {str:}, key: str -> bool {
    """Is cert-manager's webhook SERVING on the target?

    Reads the webhook Service's Endpoints. An address appears there only once the
    backing pod passes its readiness probe AND the Service selects it — i.e. only
    once a request would actually reach the webhook. Deliberately not the CRD
    (creating a ClusterIssuer goes through the validating webhook, so a present
    CRD with a webhook that is not serving fails the apply the same way) and
    deliberately not the Deployment's readyReplicas, which says a pod is ready but
    nothing about Service routing.

    Endpoints also has no required properties, so the Observe child can embed a
    bare metadata-only manifest. A Deployment cannot: `kubeconform -strict`
    rejects one without `spec`, which is exactly how the first attempt at this
    gate failed the Configuration's verify job (embedded-INVALID on xr-max).

    Absent from ocds -> False. That is the state on the very first reconcile,
    before the Observe child exists at all, and it must read as "not ready"
    rather than as an error.
    """
    _subsets = (ocds[key].Resource?.status?.atProvider?.manifest?.subsets or []) if key in ocds else []
    len([s for s in _subsets if len(s?.addresses or []) > 0]) > 0
}

gateOpen = lambda ready: bool, exists: bool -> bool {
    """Should a gated child be emitted?

    `ready` is the gate (e.g. the CNI is up). `exists` says the child is already
    in ocds, and makes the gate ONE-WAY on purpose: not emitting a child that
    exists means Crossplane deletes it, so a gate that could re-close would tear
    Flux down the moment the CNI Release blipped not-Ready during a chart
    upgrade. The gate is about install ordering, not about continuously
    enforcing a dependency.
    """
    ready or exists
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

# One step of a dotted path: read `seg` out of `cur`, where seg may carry a
# `[N]` index. Undefined for anything absent, which is what makes the whole walk
# collapse to "" rather than to a partial value.
_step = lambda cur, seg: str -> any {
    _isIdx = seg.endswith("]") and "[" in seg
    _field = seg.split("[")[0] if _isIdx else seg
    _next = cur[_field] if (typeof(cur) == "dict" and _field in cur) else Undefined
    _i = int(seg.split("[")[1].replace("]", "")) if _isIdx else 0
    (_next[_i] if (typeof(_next) == "list" and len(_next) > _i) else Undefined) if _isIdx else _next
}

resolveSource = lambda discovered: {str:}, path: str -> str {
    """Read one catalog `substitutionSources` path out of the discovered facts.

    Walks a dotted path of up to four segments, each of which may carry a `[N]`
    index — `ipReservation.domain`, `ipReservation.ipAddresses[0]`,
    `vaultIssuer.auths.eso.mountPath`.

    Four rather than unbounded, and dotted rather than a query language, for the
    reason the two-segment version gave: a general path language would need its
    own error semantics, and the failure it would introduce — an unresolvable
    path silently yielding "" — is the very one requiredSubstitutions exists to
    prevent. The bound keeps this a lookup. It grew from two to four when the
    Vault mount a cluster created became discoverable, which is genuinely nested
    (crossplane-configurations#260); raise it again only for a real path, never
    in advance.

    Returns "" for anything absent, so callers can treat "" as "not discovered",
    and a path deeper than four reads as absent rather than as a truncated
    prefix — the one outcome that would be worse than not resolving at all.
    """
    _seg = path.split(".")
    _v1 = _step(discovered, _seg[0]) if len(_seg) > 0 else Undefined
    _v2 = _step(_v1, _seg[1]) if len(_seg) > 1 else _v1
    _v3 = _step(_v2, _seg[2]) if len(_seg) > 2 else _v2
    _val = _step(_v3, _seg[3]) if len(_seg) > 3 else _v3
    _tooDeep = len(_seg) > 4
    "" if (_tooDeep or _val == Undefined or _val == None or typeof(_val) == "dict" or typeof(_val) == "list") else str(_val)
}

discoveredSubstitutions = lambda comp: cs.Component, discovered: {str:} -> {str:str} {
    """The subset of a component's substitutionSources that actually resolves.

    Only non-empty results are kept: an entry resolving to nothing must leave the
    variable UNSET so requiredSubstitutions rejects it by name, rather than
    substituting a blank that Flux would deploy without complaint.
    """
    {k: resolveSource(discovered, v) for k, v in (comp?.substitutionSources or {}) if resolveSource(discovered, v) != ""}
}

appEntries = lambda spec: {str:}, discovered: {str:} = {} -> [{str:}] {
    """FluxApps `apps[]` entries — one per enabled component of each enabled app.

    An app is not necessarily one Kustomization (dapr ships control-plane +
    template-execution), so components are expanded here and dependsOn is
    rewritten to the emitted '{app}-{component}' names.

    A component still WAITING for a discoverable value is held back rather than
    emitted blank — see componentIsPending. It is held back alone: its siblings
    keep deploying, which is what lets external-secrets install the operator on
    the reconcile before its ClusterSecretStore learns the auth mount path.
    """
    sum([[{
        name = "{}-{}".format(_n, _c.name)
        path = _c.path
        sourceRef = {kind = "OCIRepository", name = _n}
        if _c.dependsOn:
            dependsOn = [{name = depName(_n, _d)} for _d in _c.dependsOn]
        if (((_a?.components or {})[_c.name] or {})?.timeout or _c.timeout):
            timeout = ((_a?.components or {})[_c.name] or {})?.timeout or _c.timeout
        if discoveredSubstitutions(_c, discovered) | (_a?.substitute or {}) | (((_a?.components or {})[_c.name] or {})?.substitute or {}):
            # Discovered values go UNDERNEATH: an explicit value in the XR always
            # wins, so a cluster can still break out of what the platform found.
            substitute = discoveredSubstitutions(_c, discovered) | (_a?.substitute or {}) | (((_a?.components or {})[_c.name] or {})?.substitute or {})
        if ((_a?.components or {})[_c.name] or {})?.substituteFrom:
            substituteFrom = ((_a?.components or {})[_c.name] or {}).substituteFrom
        if (((_a?.components or {})[_c.name] or {})?.targetNamespace or _a?.targetNamespace):
            targetNamespace = ((_a?.components or {})[_c.name] or {})?.targetNamespace or _a?.targetNamespace
    } for _c in cat.get(_n).components if compEnabled(_c, (_a?.components or {})[_c.name] or {}) and not componentIsPending(_a, _c, discovered)] for _n, _a in enabledApps(spec)], [])
}

_compOverride = lambda app: {str:}, name: str -> {str:} {
    (app?.components or {})[name] or {}
}

_compSupplied = lambda app: {str:}, cname: str, comp: cs.Component, discovered: {str:} -> {str:} {
    """Everything that supplies a value to one component, discovered included.

    A value the platform can discover counts as supplied — that is the point of
    substitutionSources. Only RESOLVABLE ones count; an entry that reads nothing
    is still missing."""
    discoveredSubstitutions(comp, discovered) | (app?.substitute or {}) | (_compOverride(app, cname)?.substitute or {})
}

_checkedComps = lambda name: str, app: {str:} -> [cs.Component] {
    """Enabled components worth checking. One carrying substituteFrom is skipped
    — its values come from a ConfigMap/Secret resolved at build time, which
    cannot be checked statically."""
    [c for c in cat.get(name).components if compEnabled(c, _compOverride(app, c.name)) and not _compOverride(app, c.name)?.substituteFrom]
}

# A required variable that nothing supplies is one of two very different things,
# and treating them alike is what made an app impossible to enable
# (crossplane-configurations#277).
#
#   NO source declared    nothing will ever supply it — a typo or missing
#                         config. Fatal: reject at render time, by name.
#   source declared       the platform CAN discover it, just not yet — the
#                         status it reads from is produced by this same
#                         Composition. A transient state, not an error.
#
# The second used to be fatal too, which deadlocked: enabling
# `vaultIssuer.additionalAuths[eso]` and `apps.external-secrets` in one step
# aborted the whole Composition BEFORE it emitted the auth the app was waiting
# for. Nothing converged, and every other component stopped reconciling with it.
_compMissing = lambda app: {str:}, comp: cs.Component, discovered: {str:} -> [str] {
    _sup = _compSupplied(app, comp.name, comp, discovered)
    [v for v in comp.requiredSubstitutions if v not in _sup]
}

_compPending = lambda app: {str:}, comp: cs.Component, discovered: {str:} -> [str] {
    """Missing variables the component knows how to discover — waiting, not broken."""
    [v for v in _compMissing(app, comp, discovered) if v in (comp?.substitutionSources or {})]
}

_compFatal = lambda app: {str:}, comp: cs.Component, discovered: {str:} -> [str] {
    """Missing variables nothing can ever supply."""
    [v for v in _compMissing(app, comp, discovered) if v not in (comp?.substitutionSources or {})]
}

componentIsPending = lambda app: {str:}, comp: cs.Component, discovered: {str:} -> bool {
    """Hold this component back this reconcile: it is waiting on a value the
    platform will produce. Emitting it with the variable unset would deploy
    something that looks configured and is not."""
    len(_compPending(app, comp, discovered)) > 0
}

missingSubstitutions = lambda spec: {str:}, discovered: {str:} = {} -> [str] {
    """Required substitution variables that NOTHING can supply — fatal.

    Flux replaces an undefined variable with an empty string instead of failing,
    so a missing one is a silently broken deploy. Variables the component
    declares a source for are excluded here and reported by
    pendingSubstitutions instead; see the note above _compMissing.
    """
    sum([[n + "-" + c.name + ": " + v for c in _checkedComps(n, a) for v in _compFatal(a, c, discovered)] for n, a in enabledApps(spec)], [])
}

pendingSubstitutions = lambda spec: {str:}, discovered: {str:} = {} -> [str] {
    """Variables a component is WAITING for — discoverable, not yet discovered.

    Published on the status so a held-back component reads as waiting rather
    than as forgotten. Without that, an app enabled on the XR simply would not
    appear, which is the second-worst kind of silence."""
    sum([[n + "-" + c.name + ": " + v for c in _checkedComps(n, a) for v in _compPending(a, c, discovered)] for n, a in enabledApps(spec)], [])
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

validate = lambda spec: {str:}, discovered: {str:} = {} -> bool {
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
    _missing = missingSubstitutions(spec, discovered)
    assert len(_missing) == 0, "required substitution variables are not supplied (Flux substitutes empty strings rather than failing, so this would deploy silently broken): " + ", ".join(_missing)
    True
}

wildcardCertEnabled = lambda spec: {str:}, domain: str -> bool {
    """Whether to compose the wildcard Certificate for this cluster.

    Opt-IN, and gated on a domain having been DISCOVERED — a Certificate whose
    only dnsName is "*." is rejected by cert-manager, and one that is silently
    never issued is worse than one that was never composed. The domain arrives
    from the ipReservation child (status.components.ipReservation.domain), so
    this is False until that reports, and stays False when ipReservation is off.

    The Secret it fills is the one a Gateway listener names in certificateRefs:
    cert-manager writes it, the Gateway picks it up and the HTTPS listener goes
    Programmed on its own.
    """
    (((spec?.vaultIssuer or {})?.wildcardCertificate or {})?.enabled or False) and domain != ""
}
