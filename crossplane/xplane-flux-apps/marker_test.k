# Unit tests for the substitution marker. `kcl test`.
#
# The marker is one inert entry in postBuild.substitute whose only job is to be
# non-empty: kustomize-controller skips its substitution pass when there is
# nothing to substitute, and every `${VAR:-default}` fallback then reaches the
# cluster as a literal string.
_marker = {XPLANE_FLUX_APPS = "substitution-marker"}

# THE trap this file exists for. KCL treats an underscore-prefixed attribute as
# private and DROPS it from the emitted output, so a marker named
# `_XPLANE_FLUX_APPS` renders as `substitute: {}` — exactly the bug it was added
# to prevent, and without a word of complaint. Cost a debugging round on
# 2026-08-16.
test_marker_key_has_no_leading_underscore = lambda {
    _keys = [k for k, _ in _marker]
    assert len([k for k in _keys if k.startswith("_")]) == 0, "KCL drops underscore-prefixed keys from output"
    assert len(_keys) > 0
}

# Merging with an empty user map must leave the marker standing — that is the
# bare-enable case, the one that broke.
test_marker_survives_an_empty_substitute = lambda {
    _merged = _marker | {}
    assert len([k for k, _ in _merged]) == 1, "an app with no substitute still gets a non-empty map"
}

# And a user's own values must survive beside it.
test_user_values_are_kept = lambda {
    _merged = _marker | {DAPR_NAMESPACE = "dapr-system"}
    assert _merged["DAPR_NAMESPACE"] == "dapr-system"
    assert _merged["XPLANE_FLUX_APPS"] == "substitution-marker"
}
