# Unit tests for the HelmRelease helpers. `kcl test`.
import .main as flux

_release = flux.helmReleaseFromRepo("test-nginx", "nginx", "15.0.0", "bitnami")

test_repo_helper_yields_one_release = lambda {
    assert len(_release) == 1
}

test_repo_helper_names_the_release = lambda {
    _r = _release[0]
    assert _r.metadata.name == "test-nginx"
}

test_repo_helper_wires_the_chart_to_a_helmrepository = lambda {
    _chart = _release[0].spec.chart.spec
    assert _chart.chart == "nginx"
    assert _chart.version == "15.0.0"
    assert _chart.sourceRef.kind == "HelmRepository"
    assert _chart.sourceRef.name == "bitnami"
}
