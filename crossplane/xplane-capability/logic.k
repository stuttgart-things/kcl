"""
Pure decisions, separated from rendering so they can be tested without a
Crossplane request. main.k does the plumbing; everything that can be WRONG lives
here.
"""

import xplane_capability_catalog.main as cat

# Catalog defaults overlaid with the XR's values. Only keys the catalog knows
# are kept — unknownFields turns the rest into an error rather than a value that
# quietly disappears.
placement = lambda capName: str, given: {str:} -> {str:str} {
    _c = cat.get(capName)
    _known = cat.fields(capName)
    _over = {k: str(given[k]) for k in given if k in _known}

    # Built key by key rather than with `|`: KCL treats a union between a
    # schema-typed dict and an override of the same key as a CONFLICT and
    # aborts, which would make stating a default on the XR — the one thing an
    # override is for — an error.
    {k: (_over[k] if k in _over else _c.defaults[k]) for k in _c.defaults} | {k: _over[k] for k in _over if k not in _c.defaults}
}

# Empty string counts as missing. An XRD default or a half-filled values file
# reaches us as "" rather than as an absent key, and "" is exactly as unusable
# as absent for a node name.
missingRequired = lambda capName: str, given: {str:} -> [str] {
    _p = placement(capName, given)
    [f for f in cat.get(capName).required if f not in _p or _p[f] == ""]
}

# A typo'd placement key would otherwise be dropped in silence and surface much
# later as a provider error naming a field the user never wrote.
unknownFields = lambda capName: str, given: {str:} -> [str] {
    _known = cat.fields(capName)
    sorted([k for k in given if k not in _known])
}

# One message listing everything wrong with every capability, rather than
# failing on the first. A render is all-or-nothing, so fixing one field at a
# time costs a full reconcile per field.
problems = lambda enabled: [str], givenFor: {str:{str:}} -> [str] {
    sorted([n + ": missing required placement " + str(missingRequired(n, givenFor[n] or {})) for n in enabled if len(missingRequired(n, givenFor[n] or {})) > 0] + [n + ": unknown placement fields " + str(unknownFields(n, givenFor[n] or {})) + " — known: " + str(cat.fields(n)) for n in enabled if len(unknownFields(n, givenFor[n] or {})) > 0])
}

validate = lambda spec: {str:}, enabled: [str], givenFor: {str:{str:}} -> bool {
    """Everything that must hold before a single object is emitted.

    Lives in a lambda rather than at the top of main.k so it runs when it is
    called — a module-level assert fires during `kcl test` too, where there is
    no request and every field is legitimately absent.

    Guarded on `enabled` for the same reason: a Capability XR with nothing
    switched on emits nothing, so the refs it would need are not yet facts about
    anything.
    """
    _p = problems(enabled, givenFor)
    assert len(_p) == 0, "capability configuration is incomplete: " + "; ".join(_p)
    assert len(enabled) == 0 or spec?.clusterName, "spec.clusterName is required"
    assert len(enabled) == 0 or spec?.kubernetesProviderConfigRef, "spec.kubernetesProviderConfigRef is required — it names the ClusterProviderConfig for the TARGET cluster"
    True
}
