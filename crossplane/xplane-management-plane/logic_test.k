# Unit tests for the management-plane logic. `kcl test`.
# These are the rules that would otherwise only be observable on a live cluster.
import .logic as l

_min = {clusterName = "mgmt-1"}

test_refs_derive_from_cluster_name = lambda {
    assert l.helmRef(_min) == "mgmt-1-helm"
    assert l.kubernetesRef(_min) == "mgmt-1-kubernetes"
}

test_explicit_refs_win = lambda {
    _s = {clusterName = "mgmt-1", helmProviderConfigRef = "other-helm"}
    assert l.helmRef(_s) == "other-helm"
    assert l.kubernetesRef(_s) == "mgmt-1-kubernetes", "the other ref still derives"
}

test_profile_defaults_to_machinery = lambda {
    assert l.profileName({}) == "machinery"
    assert l.profileName({profile = "machinery"}) == "machinery"
}

# The catalog carries the fleet's version; an XR may sit behind it. A cluster
# mid-incident must be able to stay on an older core while the catalog moves.
test_crossplane_version_can_be_overridden = lambda {
    assert l.crossplaneVersion(_min) == "2.3.3"
    assert l.crossplaneVersion({clusterName = "c", crossplaneVersion = "2.2.1"}) == "2.2.1"
}

test_namespace_defaults_from_the_profile = lambda {
    assert l.targetNamespace(_min) == "crossplane-system"
    assert l.targetNamespace({clusterName = "c", namespace = "xp"}) == "xp"
}

# An override replaces the WHOLE reference, not just the tag: the registry a
# package comes from is load-bearing (function-kcl lives on the other mirror on
# purpose), so a tag-only override would silently keep the catalog's registry.
test_package_override_replaces_the_whole_reference = lambda {
    _s = {clusterName = "c", packageOverrides = {
        "stuttgart-things-crossplane-configurations-platform" = "ghcr.io/stuttgart-things/crossplane-configurations/platform:v0.3.9"
    }}
    _p = [x for x in l.packages(_s) if x.name == "stuttgart-things-crossplane-configurations-platform"][0]
    assert _p.package.endswith(":v0.3.9")
    _untouched = [x for x in l.packages(_s) if x.name == "function-kcl"][0]
    assert _untouched.package.startswith("xpkg.upbound.io/")
}

# An override naming a package the profile does not carry does nothing at all —
# the caller believes a version is pinned and it is not. Rejected instead.
test_unknown_override_is_rejected = lambda {
    _s = {clusterName = "c", packageOverrides = {"platform" = "ghcr.io/x/platform:v1"}}
    assert l.unknownOverrides(_s) == ["platform"], "the short name is NOT the CR name here"
    assert l.unknownOverrides(_min) == []
}

test_package_api_version_defaults_to_v1 = lambda {
    _pkgs = l.packages(_min)
    _cfg = [p for p in _pkgs if p.kind == "Configuration"][0]
    assert l.packageApiVersion(_cfg) == "pkg.crossplane.io/v1"
    _ar = [p for p in _pkgs if p.name == "function-auto-ready"][0]
    assert l.packageApiVersion(_ar) == "pkg.crossplane.io/v1beta1", "functions are split across v1 and v1beta1"
}

# The gates exist because the CRDs the later objects need are installed by the
# earlier ones. Emitting everything at once still converges, but buries the real
# errors of a broken build under minutes of expected ones.
test_gates_wait_for_the_stage_below = lambda {
    assert not l.packagesOpen(False, 0), "no packages before Crossplane is up"
    assert l.packagesOpen(True, 0)
    assert not l.providerConfigsOpen(False, 0), "no provider configs before the providers exist"
    assert l.providerConfigsOpen(True, 0)
}

# EVERY gate is one-way. Not emitting a composed resource is how Crossplane
# deletes it, so a gate that closed again would tear down what it just built —
# a Crossplane deployment briefly NotReady would uninstall the whole fleet's
# packages.
test_gates_never_close_again = lambda {
    assert l.packagesOpen(False, 3), "already-emitted packages keep being emitted"
    assert l.providerConfigsOpen(False, 1)
}

# Two thirds of what ends up on the cluster is never named. Surfaced so the
# status can answer "what is actually installed here".
test_transitive_packages_are_reported = lambda {
    _t = l.transitivePackages(_min)
    assert "ansible-run" in _t
    assert "flux-apps" in _t
    assert len(_t) >= 6
}

test_validate_requires_a_target = lambda {
    assert l.validate(_min)
    assert l.helmRef({}) == "", "nothing to derive from, so validate would reject it"
}

# Binding a provider ServiceAccount BY NAME is the trap #251 fixed — the name
# carries a per-revision hash, so the binding silently applies to nothing. The
# group is the stable subject.
test_rbac_binds_the_group_not_a_service_account = lambda {
    assert l.rbacSubjectGroup == "system:serviceaccounts:crossplane-system"
}

# On by default: a management cluster without it has every XRD and can
# reconcile none of them, which presents as a hang rather than an error.
test_cluster_admin_rbac_defaults_on = lambda {
    assert l.clusterAdminEnabled({})
    assert l.clusterAdminEnabled({clusterName = "c"})
    assert not l.clusterAdminEnabled({clusterName = "c", clusterAdminRbac = False})
}

# --- provider config readiness (crossplane-configurations#294) ---------------

# The default SuccessfulCreate leaves an Object managing a ClusterProviderConfig
# at Ready=False Creating FOREVER — measured on a live cluster, with the
# identical Object shape managing a ConfigMap going ready in seconds. One stuck
# ProviderConfig holds the entire ManagementPlane, so this must not silently
# fall back to the default.
test_provider_config_readiness_is_not_the_default = lambda {
    assert l.providerConfigReadiness.policy == "DeriveFromCelQuery", "SuccessfulCreate never marks this kind ready"
    assert l.providerConfigReadiness.celQuery == "true"
}

# AllTrue looks like the tidy choice for an object with no conditions — it is
# not. It evaluates, and returns FALSE on an empty condition list
# (Ready=False Unavailable), which is why the query is explicit instead.
test_provider_config_readiness_is_not_alltrue = lambda {
    assert l.providerConfigReadiness.policy != "AllTrue"
    assert l.providerConfigReadiness.policy != "SuccessfulCreate"
}

test_crd_name_is_derived_from_the_provider_config = lambda {
    """Das Gate braucht den CRD-Namen der ProviderConfig, nicht den eines Pakets.

    Ein Provider-Paket meldet Healthy, BEVOR seine CRDs ausgeliefert werden.
    crossplane-configurations#294.
    """
    assert l.providerConfigCrd({apiVersion = "helm.m.crossplane.io/v1beta1", kind = "ClusterProviderConfig"}) == "clusterproviderconfigs.helm.m.crossplane.io"
    assert l.providerConfigCrd({apiVersion = "kubernetes.m.crossplane.io/v1alpha1", kind = "ClusterProviderConfig"}) == "clusterproviderconfigs.kubernetes.m.crossplane.io"
    assert l.providerConfigCrd({apiVersion = "opentofu.m.upbound.io/v1beta1", kind = "ClusterProviderConfig"}) == "clusterproviderconfigs.opentofu.m.upbound.io"
    assert l.providerConfigCrd({apiVersion = "x.example.com/v1", kind = "ProviderConfig"}) == "providerconfigs.x.example.com"
}

test_unmapped_kind_is_not_gated_instead_of_guessed = lambda {
    """Ein unbekanntes kind liefert "" — der Aufrufer wartet dann NICHT darauf.

    Einen Plural zu raten ist der Weg, auf eine CRD zu warten, die nie so hiess.
    """
    assert l.providerConfigCrd({apiVersion = "x.example.com/v1", kind = "Etwas"}) == ""
    assert l.providerConfigCrds([{apiVersion = "x.example.com/v1", kind = "Etwas"}]) == []
}

test_crd_list_is_deduplicated_and_stable = lambda {
    """Zwei ProviderConfigs derselben Gruppe ergeben EIN Observe-Object."""
    _pcs = [
        {apiVersion = "helm.m.crossplane.io/v1beta1", kind = "ClusterProviderConfig"}
        {apiVersion = "helm.m.crossplane.io/v1beta1", kind = "ClusterProviderConfig"}
        {apiVersion = "kubernetes.m.crossplane.io/v1alpha1", kind = "ClusterProviderConfig"}
    ]
    assert l.providerConfigCrds(_pcs) == [
        "clusterproviderconfigs.helm.m.crossplane.io"
        "clusterproviderconfigs.kubernetes.m.crossplane.io"
    ]
}

test_crd_observe_object_names_a_cluster_provider_config = lambda {
    """providerConfigRef.kind darf NICHT fehlen.

    Ohne kind sucht provider-kubernetes eine NAMESPACED ProviderConfig, findet
    keine und legt das Object gar nicht erst an — waehrend die XR es brav in
    resourceRefs fuehrt und "Unsynced resources" fuer etwas meldet, das es nicht
    gibt. Genau so ist 0.5.0 ausgeliefert worden, mit gruenen Unit-Tests.
    """
    _o = l.crdObserveObject("x-crd-helm", "default", "clusterproviderconfigs.helm.m.crossplane.io", "ziel-kubernetes")
    assert _o.spec.providerConfigRef.kind == "ClusterProviderConfig"
    assert _o.spec.providerConfigRef.name == "ziel-kubernetes"
}

test_crd_observe_object_observes_and_never_writes = lambda {
    """Observe-only, und das Manifest identifiziert nur — es beschreibt nicht.

    Eine managementPolicy, die schreiben darf, wuerde hier eine echte CRD auf
    dem Ziel mit einem leeren Manifest ueberschreiben.
    """
    _o = l.crdObserveObject("x-crd-helm", "default", "clusterproviderconfigs.helm.m.crossplane.io", "ziel-kubernetes")
    assert _o.spec.managementPolicies == ["Observe"]
    _m = _o.spec.forProvider.manifest
    assert _m.apiVersion == "apiextensions.k8s.io/v1"
    assert _m.kind == "CustomResourceDefinition"
    assert _m.metadata.name == "clusterproviderconfigs.helm.m.crossplane.io"
    assert "spec" not in _m
}

test_crd_observe_object_carries_the_composition_resource_name = lambda {
    """Ohne die Annotation ordnet Crossplane das Object bei jedem Render neu zu."""
    _o = l.crdObserveObject("x-crd-helm", "default", "c.helm.m.crossplane.io", "ziel")
    assert _o.metadata.annotations["krm.kcl.dev/composition-resource-name"] == "x-crd-helm"
    assert _o.metadata.namespace == "default"
}
