import .logic as l

test_provider_defaults_to_cilium = lambda {
    assert l.provider({}) == "cilium"
    assert l.provider({provider = "cilium"}) == "cilium"
}

test_chart_defaults = lambda {
    _c = l.chart({})
    assert _c.name == "cilium"
    assert _c.repository == "https://helm.cilium.io/"
    assert _c.version == "1.19.6"
}

test_chart_overrides = lambda {
    _c = l.chart({
        chart = {version = "1.20.0", repository = "oci://example.test/charts"}
    })
    assert _c.version == "1.20.0"
    assert _c.repository == "oci://example.test/charts"
    # name is not overridable — it identifies the provider
    assert _c.name == "cilium"
}

test_api_host_derives_from_cluster_name = lambda {
    assert l.apiServerHost({clusterName = "kind-test1"}) == "kind-test1-control-plane"
}

test_api_host_explicit_wins = lambda {
    assert l.apiServerHost({clusterName = "kind-test1", cilium = {k8sServiceHost = "10.31.103.22"}}) == "10.31.103.22"
}

test_kube_proxy_replacement_defaults_on = lambda {
    assert l.kubeProxyReplacement({}) == True
}

test_explicit_false_is_not_swallowed = lambda {
    # The `or True` trap: an explicit false must survive.
    assert l.kubeProxyReplacement({
        cilium = {kubeProxyReplacement = False}
    }) == False
}

test_values_wire_the_api_server = lambda {
    _v = l.values({clusterName = "kind-test1"})
    assert _v.kubeProxyReplacement == True
    assert _v.k8sServiceHost == "kind-test1-control-plane"
    assert _v.k8sServicePort == 6443
    assert _v.ipam.mode == "kubernetes"
    assert _v.operator.replicas == 1
}

test_api_server_omitted_without_kube_proxy_replacement = lambda {
    # With a real kube-proxy present, cilium discovers the API server the normal
    # way; pinning a host would be wrong, not merely redundant.
    _v = l.values({clusterName = "kind-test1", cilium = {kubeProxyReplacement = False}})
    assert "k8sServiceHost" not in _v
    assert "k8sServicePort" not in _v
}

test_raw_values_win = lambda {
    _v = l.values({clusterName = "kind-test1", values = {operator = {replicas = 2}, hubble = {enabled = True}}})
    assert _v.operator.replicas == 2
    assert _v.hubble.enabled == True
    # untouched computed values survive the merge
    assert _v.k8sServiceHost == "kind-test1-control-plane"
}

test_validate_accepts_cluster_name = lambda {
    assert l.validate({clusterName = "kind-test1"}) == True
}

test_validate_accepts_explicit_host = lambda {
    assert l.validate({helmProviderConfigRef = "x-helm", cilium = {k8sServiceHost = "1.2.3.4"}}) == True
}

test_validate_accepts_kube_proxy_cluster = lambda {
    # No clusterName and no host, but kube-proxy is present — nothing to resolve.
    assert l.validate({helmProviderConfigRef = "x-helm", cilium = {kubeProxyReplacement = False}}) == True
}

test_gate_readiness_is_not_successful_create = lambda {
    # crossplane-configurations#439: with provider-kubernetes' default readiness
    # the gate Object is ready as soon as it exists. The Release is not composed
    # while the gate is closed, so function-auto-ready then marked the XR Ready
    # with no CNI installed.
    assert l.gateReadiness().policy == "DeriveFromCelQuery"
}

test_gate_cel_guards_every_hop = lambda {
    # A missing field is an evaluation error in CEL, not a false, so each hop
    # needs its own has().
    assert l.gateReadiness().celQuery == 'has(object.status) && has(object.status.atProvider) && has(object.status.atProvider.clusterType) && object.status.atProvider.clusterType != ""'
}

test_cilium_minor_is_parsed = lambda {
    # the chart default
    assert l.ciliumMinor({}) == "1.19"
    assert l.ciliumMinor({
        chart = {version = "1.20.1"}
    }) == "1.20"
}

test_gateway_api_version_pairs_with_the_cilium_minor = lambda {
    # From the cilium docs: 1.19 supports Gateway API v1.4.1, 1.20 v1.6.1.
    assert l.gatewayAPIVersion({
        gatewayAPI = {enabled = True}
    }) == "1.4.1"
    assert l.gatewayAPIVersion({chart = {version = "1.20.1"}, gatewayAPI = {enabled = True}}) == "1.6.1"
}

test_gateway_api_version_explicit_wins = lambda {
    assert l.gatewayAPIVersion({
        gatewayAPI = {enabled = True, version = "1.5.1"}
    }) == "1.5.1"
}

test_gateway_api_version_unknown_minor_is_empty = lambda {
    # Not guessed — validate() turns this into a render error naming the fix.
    assert l.gatewayAPIVersion({chart = {version = "1.21.0"}, gatewayAPI = {enabled = True}}) == ""
}

test_gateway_api_chart_defaults_and_overrides = lambda {
    _c = l.gatewayAPIChart({
        gatewayAPI = {enabled = True}
    })
    assert _c.repository == "oci://ghcr.io/stuttgart-things/charts"
    assert _c.name == "gateway-api-crds"
    assert _c.version == "1.4.1"
    _o = l.gatewayAPIChart({
        gatewayAPI = {enabled = True, chart = {repository = "oci://example.test/charts", name = "gw"}}
    })
    assert _o.repository == "oci://example.test/charts"
    assert _o.name == "gw"
}

test_gateway_api_off_by_default = lambda {
    assert l.gatewayAPIEnabled({}) == False
    assert "gatewayAPI" not in l.values({clusterName = "kind-1"})
    assert l.values({clusterName = "kind-1", gatewayAPI = {enabled = True}}).gatewayAPI.enabled == True
}
