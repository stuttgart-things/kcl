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

    {
        kubeProxyReplacement = _kpr
        ipam = {mode = _c?.ipamMode or "kubernetes"}
        operator = {replicas = _c?.operatorReplicas or 1}
    } | _api | (spec?.values or {})
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
    True
}
