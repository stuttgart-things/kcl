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

# The CRD a ProviderConfig entry needs before it can be applied at all.
#
# WHY THIS EXISTS. A provider PACKAGE reports Healthy BEFORE its CRDs are
# served. Gating the ProviderConfigs on package health therefore opens a window
# -- two minutes on u26-rke2-1, none on mgmt-test1 -- in which the apply hits a
# kind the API server does not know yet. That alone would be a hiccup; what
# makes it permanent is provider-kubernetes: once its first create fails, the
# Object stays Ready=False/Creating forever, even though every later reconcile
# succeeds and the resource demonstrably exists. Thirty hours of a false
# Ready=False on u26-rke2-1-mgmt, and it would block a whole ClusterStack that
# composes a ManagementPlane. See crossplane-configurations#294.
#
# Derived from the ProviderConfig itself, not from the package: the question is
# "can I create THIS kind", which is a property of its own group -- not of
# whatever CRDs some package happens to register.
providerConfigCrd = lambda pc -> str {
    """CRD name for a ProviderConfig entry, e.g. clusterproviderconfigs.helm.m.crossplane.io.

    Only the kinds we actually emit are mapped. An unmapped kind returns "" and
    the caller then does NOT gate on it -- guessing a plural is how one ends up
    waiting forever for a CRD that never had that name.
    """
    _group = pc.apiVersion.split("/")[0]
    _plural = {
        "ClusterProviderConfig" = "clusterproviderconfigs"
        "ProviderConfig" = "providerconfigs"
    }[pc.kind] or ""
    "{}.{}".format(_plural, _group) if _plural else ""
}

# The Observe-only Object that watches one CRD on the target.
#
# Lives here, not in main.k, so its SHAPE is testable. It was not, and the first
# version shipped without providerConfigRef.kind: provider-kubernetes then looked
# for a namespaced ProviderConfig, found none, and never created the Object at
# all -- while the XR dutifully listed it in resourceRefs and reported "Unsynced
# resources" for something that did not exist. Every unit test was green.
crdObserveObject = lambda name: str, ns: str, crd: str, pcRef: str -> any {
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = name
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = name}
        }
        spec = {
            managementPolicies = ["Observe"]
            # kind is NOT optional -- see above.
            providerConfigRef = {
                name = pcRef
                kind = "ClusterProviderConfig"
            }
            # Metadata only, and that survives the verify pipeline for a reason
            # worth knowing: kubeconform ships NO schema for
            # CustomResourceDefinition, so with -ignore-missing-schemas it is
            # Skipped rather than validated. Should a CRD schema ever land in
            # that set this would start failing -- CRD v1 requires `spec` --
            # exactly like the metadata-only Deployment in xplane-platform 0.22.0.
            forProvider.manifest = {
                apiVersion = "apiextensions.k8s.io/v1"
                kind = "CustomResourceDefinition"
                metadata = {name = crd}
            }
        }
    }
}

# Distinct CRDs to wait for, in stable order.
providerConfigCrds = lambda pcs: [any] -> [str] {
    _all = [providerConfigCrd(pc) for pc in pcs]
    sorted({c: "" for c in _all if c})
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

# --- RBAC -------------------------------------------------------------------
# Crossplane's providers run as ServiceAccounts in crossplane-system with
# per-revision generated names, so binding one BY NAME is the trap #251 fixed:
# the name carries a hash and the binding silently applies to nothing. The
# group `system:serviceaccounts:crossplane-system` is the stable subject.
#
# cluster-admin, and on purpose. On a MANAGEMENT cluster the providers create
# arbitrary cluster content by definition — that is the job. The narrower
# ClusterRoles the machinery play fetches from raw URLs
# (provider-kubernetes-remote-cluster, provider-kubernetes-ip-reservation) bind
# the SAME group, so this subsumes both and they stop being a precondition.
#
# Default on: a management cluster without it has every XRD and can reconcile
# none of them, which presents as a hang rather than an error. Turn it off only
# if something else grants the equivalent.
clusterAdminEnabled = lambda spec: {str:} -> bool {
    spec?.clusterAdminRbac if "clusterAdminRbac" in spec else True
}

rbacSubjectGroup = "system:serviceaccounts:crossplane-system"

# --- provider config readiness ----------------------------------------------

# NOT the default SuccessfulCreate. provider-kubernetes never marks an Object
# ready when the managed manifest is a ClusterProviderConfig — measured on a
# live cluster, not guessed (crossplane-configurations#294):
#
#   SuccessfulCreate     Ready=False Creating       never evaluated
#   AllTrue              Ready=False Unavailable    evaluated, and false on an
#                                                   empty condition list
#   DeriveFromCelQuery   Ready=True  Available
#
# Three probes of the same Object shape across two target clusters behaved
# alike, while the identical shape managing a ConfigMap went ready in seconds —
# so it is the managed KIND, not the provider, the target cluster or a race.
#
# The cost of getting this wrong is out of proportion to the cause: ONE stuck
# ProviderConfig Object keeps the whole ManagementPlane from ever reporting
# ready, and with managementPlaneEnabled it would hold the entire ClusterStack.
# u26-rke2-1-mgmt sat that way for 31 hours.
#
# `true` is the honest query, not a workaround in disguise: a ProviderConfig has
# no lifecycle and no conditions. It is ready once it exists — which is exactly
# what SuccessfulCreate is supposed to express and, for this kind, does not.
providerConfigReadiness = {
    policy = "DeriveFromCelQuery"
    celQuery = "true"
}
