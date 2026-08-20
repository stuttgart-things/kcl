"""
Pure decisions, separated from rendering so they can be tested without a
Crossplane request. main.k does the plumbing; everything that can be WRONG lives
here.
"""

import xplane_capability_catalog.main as cat

# Catalog defaults overlaid with the XR's values. Only keys the catalog knows
# are kept — unknownFields turns the rest into an error rather than a value that
# quietly disappears.
# Scalars become strings, everything else is passed through untouched.
# EnvironmentConfig data is not string-only, and the one list in the catalog —
# ansible's collection set — is handed to Tekton as a parameter, where a
# stringified list is rejected with ParameterTypeMismatch: an error naming the
# Tekton parameter and nothing about where the value came from. A YAML author
# writing `vlanTag: 102` still has to be caught, so ints and bools keep being
# coerced.
_coerce = lambda v: any -> any {
    v if typeof(v) in ["list", "dict"] else str(v)
}

placement = lambda capName: str, given: {str:} -> {str:} {
    _c = cat.get(capName)
    _known = cat.fields(capName)
    _over = {k: _coerce(given[k]) for k in given if k in _known}

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

validateStores = lambda enabled: [str], vaultFor: {str:{str:}}, server: str, authMountPath: str -> bool {
    """The store half of validate().

    A capability that names its own KV mount needs a Vault server and an auth
    mount to reach it. Both have derivations, so the failure is not "you forgot
    a field" but "nothing could be derived": `authMountPath` falls back to
    `<clusterName>-eso`, which is only absent when clusterName is.
    """
    _needing = [n for n in enabled if not (vaultFor[n] or {})?.secretStoreName and (vaultFor[n] or {})?.mount]
    _noServer = [n for n in _needing if not ((vaultFor[n] or {})?.server or server)]
    assert len(_noServer) == 0, "these capabilities create a ClusterSecretStore but no Vault server is set (spec.vault.server, or per capability): " + ", ".join(_noServer)
    assert len(_needing) == 0 or authMountPath, "spec.vault.auth.mountPath could not be derived — it defaults to <clusterName>-eso, so set spec.clusterName"
    True
}

schema Readiness:
    policy: str
    celQuery?: str

# Which readiness policy a managed KIND gets. Here rather than inline in main.k
# so the choice is testable: both directions are failures that hide rather than
# break, so nothing else would catch a change.
readinessFor = lambda kind: str -> Readiness {
    Readiness {policy = "DeriveFromCelQuery", celQuery = "true"} if kind in ["EnvironmentConfig", "ClusterProviderConfig"] else Readiness {policy = "DeriveFromObject"}
}

# Which namespace a capability's credentials Secret belongs in. Beside the
# provider by default; a capability whose consumer reads it elsewhere names the
# placement key holding that namespace. Here rather than inline so it is
# testable: a Secret in the wrong namespace does not fail, it is simply never
# read — the consumer reports a missing credential and points at itself.
credentialsNamespace = lambda capName: str, placementOf: {str:}, providerNs: str -> str {
    _f = cat.get(capName)?.credentialsNamespaceField
    str(placementOf[_f]) if _f else providerNs
}

# Der Name der komponierten Object-Ressource AUF DEM MANAGEMENT-CLUSTER — nicht
# zu verwechseln mit dem Namen der Ressource auf dem ZIELCLUSTER, der aus
# Capability + Environment gebildet wird.
#
# clusterName MUSS hinein. Ohne das Praefix heisst das Object nur nach der
# Capability ("ansible-run-secret-store"), und zwei Capability-XRs im selben
# Namespace kollidieren zwangslaeufig auf jeder Capability, die beide aktiviert
# haben. Am 2026-08-20 auf kind3 passiert: u26-rke2-1-capability hielt die
# ansible-run-Namen, ein neues seed-labda-1-capability fuehrte dieselben Objects
# in seinen resourceRefs und blieb auf Ready=False stehen — waehrend seine
# vspherevm-Haelfte durchlief, weil u26 zufaellig proxmoxvm faehrt.
#
# Ueberschrieben wurde nichts: Crossplane beansprucht keine Ressource, die
# bereits das crossplane.io/composite-Label eines anderen Composites traegt.
# Darauf zu bauen waere aber falsch — die beiden XRs zeigten auf verschiedene
# Cluster UND verschiedene Vaults, und ohne diese Sicherung haette das neue XR
# den Store des anderen Clusters auf den falschen Vault umgebogen, still und
# ohne Meldung. Siehe crossplane-configurations#356.
#
# ENVIRONMENT GEHOERT DAZU, nicht nur clusterName. Das XRD sagt zu spec.environment
# ausdruecklich "Set it when one cluster serves two environments (labda AND
# labul)" -- der vorgesehene Weg fuer zwei Umgebungen sind also ZWEI
# Capability-XRs auf demselben Cluster. Praefixt man nur mit clusterName, tragen
# deren Objects fuer dieselbe Capability wieder denselben Namen, und die
# Kollision ist zurueck, ausgerechnet im vom XRD vorgesehenen Fall. Fuer
# VERSCHIEDENE Capabilities (proxmoxvm vs vspherevm) reicht clusterName, weil der
# Capability-Name im Suffix steckt -- das deckt aber nur die Haelfte ab.
#
# Hier statt inline in main.k, weil ein Fehler hier nicht bricht sondern
# verwechselt: ein falsches Praefix erzeugt eine Kollision, die erst auf einem
# zweiten Cluster oder in einer zweiten Umgebung sichtbar wird.
resourceName = lambda clusterName: str, environment: str, suffix: str -> str {
    assert clusterName, "clusterName is required — composed object names must be unique per cluster"
    assert environment, "environment is required — one cluster may serve two of them"
    clusterName + "-" + environment + "-" + suffix
}
