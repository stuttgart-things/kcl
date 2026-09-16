"""
Pure logic for the cni Configuration — no option("params"), so every rule here
is unit-testable with `kcl test`. main.k is the thin render entry point.

The interesting part is values resolution, not resource emission: a CNI on a
kind-style cluster needs a handful of settings that are *cluster-shape facts*
(is there a kube-proxy? where is the API server?) rather than free-form Helm
values, and getting them wrong deadlocks the cluster silently. Those get named
fields with defaults derived from clusterName; everything else is passthrough.
"""

_CHART_DEFAULTS = {
    cilium = {
        name = "cilium"
        repository = "https://helm.cilium.io/"
        version = "1.19.6"
    }
}

chart = lambda spec: {str:} -> {str:} {
    """Chart coordinates for the selected provider, with spec overrides."""
    _p = provider(spec)
    _d = _CHART_DEFAULTS[_p]
    _c = spec?.chart or {}
    {
        name = _d.name
        repository = _c?.repository or _d.repository
        version = _c?.version or _d.version
    }
}

provider = lambda spec: {str:} -> str {
    _p = spec?.provider or "cilium"
    assert _p in _CHART_DEFAULTS, "unsupported CNI provider '" + _p + "' — supported: " + ", ".join(sorted(_CHART_DEFAULTS))
    _p
}

apiServerHost = lambda spec: {str:} -> str {
    """Where cilium reaches the API server when it replaces kube-proxy.

    A kind cluster has NO kube-proxy, so nothing programs the 10.96.0.1 service
    VIP until cilium is up — and cilium cannot come up if it needs that VIP to
    talk to the API server. Pointing at the control-plane container by name
    breaks the circular dependency. `{clusterName}-control-plane` is exactly the
    container kind creates, which is why clusterName is enough on its own.
    """
    _c = spec?.cilium or {}
    _c?.k8sServiceHost or ("{}-control-plane".format(spec.clusterName) if spec?.clusterName else "")
}

# Readiness of the RemoteCluster gate Object.
#
# It used to be provider-kubernetes' default (SuccessfulCreate), i.e. ready the
# moment the Object exists. While the gate is closed the Release is not composed
# at all, so "every composed resource is ready" was trivially true and
# function-auto-ready marked the whole XR Ready before a CNI had been installed
# — with status.ready correctly False right next to it. Consumers that gate on
# the condition (xplane-platform does) then opened onto NotReady nodes.
# See crossplane-configurations#439.
#
# A lambda, not a constant: a non-underscore top-level value would be rendered
# as an output key of the module.
_GATE_CEL = 'has(object.status) && has(object.status.atProvider) && has(object.status.atProvider.clusterType) && object.status.atProvider.clusterType != ""'

gateReadiness = lambda -> {str:str} {
    """Readiness for the gate Object: the RemoteCluster has actually resolved.

    The CEL runs against the OBSERVED manifest — `object` is the RemoteCluster
    provider-kubernetes read back — so it asserts exactly the field main.k's
    render gate reads out of ocds. has() guards each hop, because a missing
    field is an evaluation error in CEL rather than a false.
    """
    {
        policy = "DeriveFromCelQuery"
        celQuery = _GATE_CEL
    }
}

# Gateway API CRDs. Cilium enables its Gateway controller only if they exist
# WHEN IT STARTS; installed afterwards, gatewayAPI.enabled is a no-op until the
# operator and agents restart (cilium docs). So the CRDs are a Release of their
# own, and the cilium Release waits for it — see main.k.
#
# Upstream publishes no chart, only standard-install.yaml, so this points at the
# one that vendors it: stuttgart-things/stuttgart-things
# crossplane/platform/baseline/gateway-api-crds. Its chart version IS the
# Gateway API version.
_GATEWAY_API_CHART = {
    repository = "oci://ghcr.io/stuttgart-things/charts"
    name = "gateway-api-crds"
}

# Which Gateway API version a cilium minor supports, from the cilium docs. An
# unknown minor is not guessed: gatewayAPI then needs an explicit version, and
# validate() says so.
_GATEWAY_API_FOR_CILIUM = {
    "1.19" = "1.4.1"
    "1.20" = "1.6.1"
}

ciliumMinor = lambda spec: {str:} -> str {
    """`1.19.6` -> `1.19`; "" when the version is not shaped like that."""
    _parts = chart(spec).version.split(".")
    ".".join([_parts[0], _parts[1]]) if len(_parts) >= 2 else ""
}

gatewayAPIEnabled = lambda spec: {str:} -> bool {
    """`or False` is safe here: absent and false mean the same thing."""
    (spec?.gatewayAPI or {})?.enabled or False
}

gatewayAPIVersion = lambda spec: {str:} -> str {
    """Explicit wins; otherwise the version paired with the cilium minor."""
    _g = spec?.gatewayAPI or {}
    _g?.version or _GATEWAY_API_FOR_CILIUM[ciliumMinor(spec)] or ""
}

gatewayAPIChart = lambda spec: {str:} -> {str:str} {
    """Chart coordinates for the CRDs, with spec overrides."""
    _g = (spec?.gatewayAPI or {})?.chart or {}
    {
        repository = _g?.repository or _GATEWAY_API_CHART.repository
        name = _g?.name or _GATEWAY_API_CHART.name
        version = gatewayAPIVersion(spec)
    }
}

kubeProxyReplacement = lambda spec: {str:} -> bool {
    """`or True` would swallow an explicit false, so test for the key."""
    _c = spec?.cilium or {}
    _c.kubeProxyReplacement if "kubeProxyReplacement" in _c else True
}

values = lambda spec: {str:} -> {str:} {
    """Helm values for the release: computed defaults, then spec.values on top.

    spec.values wins on conflict — it is the escape hatch for anything this
    module does not model, including overriding what it computed.
    """
    _c = spec?.cilium or {}
    _kpr = kubeProxyReplacement(spec)
    _host = apiServerHost(spec)

    # Only meaningful with kubeProxyReplacement on, and an empty host would make
    # cilium fail to start rather than fall back — so omit both unless resolved.
    _api = {
        k8sServiceHost = _host
        k8sServicePort = _c?.k8sServicePort or 6443
    } if (_kpr and _host) else {}

    # gatewayAPI follows spec.gatewayAPI.enabled — one switch, not two that can
    # disagree. spec.values still wins, as always.
    _gw = {gatewayAPI = {enabled = True}} if gatewayAPIEnabled(spec) else {}

    {
        kubeProxyReplacement = _kpr
        ipam = {mode = _c?.ipamMode or "kubernetes"}
        operator = {replicas = _c?.operatorReplicas or 1}
    } | _api | _gw | (spec?.values or {})
}

validate = lambda spec: {str:} -> bool {
    """Rules that must hold before anything is emitted.

    Vacuously true on an empty spec: that is the module being evaluated with no
    XR at all (unit tests, bare `kcl run`), not a misconfigured one.
    """
    _empty = not spec
    _ = provider(spec)

    # kubeProxyReplacement with no reachable API server address is the deadlock
    # this module exists to prevent: cilium waits on a service VIP that only
    # cilium can program. Fail at render, naming the fix.
    _resolved = apiServerHost(spec) or (spec?.values or {})?.k8sServiceHost or ""
    assert _empty or not kubeProxyReplacement(spec) or _resolved, "kubeProxyReplacement is on but no API server address could be resolved — set spec.clusterName (derives {clusterName}-control-plane) or spec.cilium.k8sServiceHost; without it cilium waits on a service VIP that only cilium can program"

    # Guessing a Gateway API version for an unknown cilium minor would install
    # CRDs cilium may not support, and the failure shows up as a Gateway that
    # never programs rather than as an install error.
    assert _empty or not gatewayAPIEnabled(spec) or gatewayAPIVersion(spec), "spec.gatewayAPI.enabled is set but no Gateway API version is known for cilium " + chart(spec).version + " — set spec.gatewayAPI.version explicitly (cilium 1.19 pairs with 1.4.1, 1.20 with 1.6.1)"
    True
}
