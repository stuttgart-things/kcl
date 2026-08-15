"""
Decision logic for the management-plane Configuration.

Separated from main.k so it can be unit-tested without Crossplane: what the
profile resolves to, which packages an override moves, and — the part worth
testing hardest — the gates. A management cluster is built in an order that
cannot be expressed by Object dependencies, because the CRDs the later objects
need are installed by the earlier ones.
"""

import xplane_crossplane_catalog as cat
import xplane_crossplane_catalog.schema as cs

# --- provider config refs --------------------------------------------------
# Same derivation as flux-init and cni: {clusterName}-helm / -kubernetes are the
# names provider-kubeconfig's RemoteCluster creates for a target cluster.
helmRef = lambda spec: {str:} -> str {
    _c = spec?.clusterName or ""
    spec?.helmProviderConfigRef or ("{}-helm".format(_c) if _c else "")
}

kubernetesRef = lambda spec: {str:} -> str {
    _c = spec?.clusterName or ""
    spec?.kubernetesProviderConfigRef or ("{}-kubernetes".format(_c) if _c else "")
}

# --- profile resolution ----------------------------------------------------
profileName = lambda spec: {str:} -> str {
    spec?.profile or "machinery"
}

profile = lambda spec: {str:} -> cs.Profile {
    cat.get(profileName(spec))
}

crossplaneVersion = lambda spec: {str:} -> str {
    """spec wins over the profile: a cluster may need to sit on an older core
    while a catalog release moves the fleet forward."""
    spec?.crossplaneVersion or profile(spec).crossplaneVersion
}

targetNamespace = lambda spec: {str:} -> str {
    spec?.namespace or profile(spec).namespace
}

# --- package overrides -----------------------------------------------------
# A map of CR name -> full package reference. Deliberately the WHOLE reference
# and not just a tag: an override that only swapped the tag would silently keep
# the catalog's registry, and the mirror a package comes from is load-bearing
# here (see the catalog's README on function-kcl).
packages = lambda spec: {str:} -> [cs.Package] {
    _over = spec?.packageOverrides or {}
    [cs.Package {
        kind = p.kind
        name = p.name
        package = _over[p.name] or p.package
        apiVersion = p.apiVersion
        pulls = p.pulls
        providerCrd = p.providerCrd
        clusterRole = p.clusterRole
    } for p in profile(spec).packages]
}

# An override naming a package the profile does not carry is a typo that would
# otherwise do nothing at all — the caller believes a version was pinned and it
# was not.
unknownOverrides = lambda spec: {str:} -> [str] {
    _named = {p.name: "" for p in profile(spec).packages}
    sorted([k for k in (spec?.packageOverrides or {}) if k not in _named])
}

# The package CR's apiVersion. Functions are split across v1 and v1beta1
# upstream and it is not guessable from the name, so the catalog states it;
# everything else is v1.
packageApiVersion = lambda p: cs.Package -> str {
    p.apiVersion or "pkg.crossplane.io/v1"
}

# --- gates -----------------------------------------------------------------
# The order is forced by CRDs, not by preference: the pkg.crossplane.io CRDs
# arrive WITH Crossplane, and each provider's ProviderConfig CRD arrives with
# that provider. Emitting everything at once still converges — the Objects
# retry — but it buries the real errors of a broken build under minutes of
# expected ones, which is how a failed bootstrap gets diagnosed as healthy.
#
# Every gate is ONE-WAY: once a resource exists it keeps being emitted. Not
# emitting a composed resource is how Crossplane deletes it, so a gate that
# closed again would tear down what it just built.
packagesOpen = lambda coreReady: bool, existing: int -> bool {
    coreReady or existing > 0
}

providerConfigsOpen = lambda packagesReady: bool, existing: int -> bool {
    packagesReady or existing > 0
}

# --- validation ------------------------------------------------------------
validate = lambda spec: {str:} -> bool {
    """Rules that must hold before anything is emitted.

    Vacuously true on an empty spec: that is the module being evaluated with no
    XR at all (unit tests, bare `kcl run`), not a misconfigured one. Same
    convention as xplane-cni.
    """
    _empty = not spec
    _unknown = unknownOverrides(spec)
    assert _empty or helmRef(spec) != "", "clusterName or helmProviderConfigRef must be set"
    assert _empty or kubernetesRef(spec) != "", "clusterName or kubernetesProviderConfigRef must be set"
    assert _unknown == [], "packageOverrides name packages this profile does not carry"
    True
}

# What arrives on the cluster without being installed by name. Surfaced on the
# status because "which packages are on this cluster" is not answerable from the
# spec: two thirds of them come through some other package's dependsOn.
transitivePackages = lambda spec: {str:} -> [str] {
    cat.transitive(profile(spec))
}
