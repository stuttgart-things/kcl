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
