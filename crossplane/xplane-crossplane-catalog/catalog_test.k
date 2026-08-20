# Unit tests for the package catalog. Run with `kcl test`.
# These validate the catalog's own invariants — no Crossplane, no cluster.
import .main as c

test_machinery_is_registered = lambda {
    assert "machinery" in c.catalog
    assert c.get("machinery").crossplaneVersion == "2.3.3"
    assert c.get("machinery").namespace == "crossplane-system"
}

# THE rule this catalog exists for, in its sharper form.
#
# Providers and Configurations carry the name Crossplane derives from their
# package path. That makes the Lock collision from
# crossplane-configurations#247 impossible rather than merely unlikely: the
# resolver keys on the SOURCE, so an existing node satisfies a dependency
# whatever it is called — but during an UPGRADE the entry is briefly gone, the
# resolver auto-installs the dependency under the derived name, and a
# short-named CR then collides with it. On u26-kind3 that took all 20
# Configurations to Healthy=False, and unpicking it is whack-a-mole because
# deleting one duplicate makes the resolver create the next.
test_providers_and_configurations_use_derived_names = lambda {
    _p = c.get("machinery")
    _named = c.byKind(_p, "Provider") + c.byKind(_p, "Configuration")
    _wrong = [x.name for x in _named if x.name != c.derivedName(x.package)]
    assert _wrong == [], "not the package-manager-derived name"
}

# The derivation itself, against the two shapes in use — a two-segment upstream
# path and our four-segment ghcr one. Pinned because everything above rests on
# it matching what Crossplane actually does.
test_derived_name_matches_crossplane = lambda {
    assert c.derivedName("xpkg.crossplane.io/crossplane-contrib/provider-helm:v1.3.0") == "crossplane-contrib-provider-helm"
    assert c.derivedName("ghcr.io/stuttgart-things/crossplane-configurations/platform:v0.3.11") == "stuttgart-things-crossplane-configurations-platform"
    assert c.derivedName("ghcr.io/stuttgart-things/provider-clusterbook-xpkg:v0.4.2") == "stuttgart-things-provider-clusterbook-xpkg"
}

# The transitive set is not empty — if it were, someone flattened the dependsOn
# declarations and the graph documentation would be silently worthless.
test_transitive_set_is_populated = lambda {
    _t = c.transitive(c.get("machinery"))
    assert len(_t) >= 6, "the dependsOn graph should carry most of the fleet"
    assert "flux-apps" in _t, "platform has pulled flux-apps since v0.3.1"
    assert "ansible-run" in _t, "both VM Configurations pull ansible-run"
}

# Every reference pins a tag. Enforced by the schema too; asserted here so the
# intent is visible where the rules are read.
test_every_package_is_pinned = lambda {
    _pkgs = c.get("machinery").packages
    assert all p in _pkgs {
        ":" in p.package and not p.package.endswith(":latest")
    }, "a floating tag would move a management cluster forward unattended"
}

# Function CR names stay SHORT (root CLAUDE.md). A long-named Function CR on the
# same registry as a dependsOn-derived one adds a duplicate Lock node and
# freezes the resolver for every package on the cluster.
test_function_names_are_short = lambda {
    _f = c.byKind(c.get("machinery"), "Function")
    assert len(_f) > 0
    assert all p in _f {
        not p.name.startswith("crossplane-contrib-")
    }, "Function CRs use the short name"
}

# Providers are the EXCEPTION and it is not an oversight: provider-helm carries
# the long, package-manager-derived name so the explicit CR and any
# dependsOn-derived one are the same Lock node. Providers own CRDs, and two of
# them fighting over ownership is worse than the duplication a Function pair
# causes.
test_provider_helm_keeps_the_long_name = lambda {
    _h = [p for p in c.byKind(c.get("machinery"), "Provider") if "provider-helm" in p.package]
    assert len(_h) == 1
    assert _h[0].name == "crossplane-contrib-provider-helm"
}

# function-kcl must stay on the upbound mirror. Our dependsOn entries use
# xpkg.crossplane.io and the package manager derives a long-named CR from that
# path; the differing mirror is what keeps the two Lock nodes distinct. Aligning
# them yields two nodes with an IDENTICAL source and every Function on the
# cluster goes Healthy=False (verified on kind1, 2026-07-18).
test_function_kcl_stays_on_the_other_mirror = lambda {
    _k = [p for p in c.byKind(c.get("machinery"), "Function") if p.name == "function-kcl"]
    assert len(_k) == 1
    assert _k[0].package.startswith("xpkg.upbound.io/")
}

# function-auto-ready v0.7.0 makes Configurations report Unhealthy, which times
# out the install wait. The ceiling is a fleet fact, not a preference.
test_function_auto_ready_stays_below_070 = lambda {
    _a = [p for p in c.byKind(c.get("machinery"), "Function") if p.name == "function-auto-ready"]
    assert len(_a) == 1
    assert _a[0].package.endswith(":v0.6.5")
}

# provider-kubernetes must NOT be an entry: every Configuration pulls it, so
# naming it would be the duplicate this catalog prevents. Asserted separately
# because it is the one absence a reader is most likely to mistake for an
# omission.
test_provider_kubernetes_is_not_installed_explicitly = lambda {
    _pkgs = c.get("machinery").packages
    assert all p in _pkgs {
        p.name != "provider-kubernetes"
    }, "provider-kubernetes arrives through every Configuration's dependsOn"
}

# Each provider gets one in-cluster ProviderConfig, and they carry no
# credentials — the ServiceAccount is the identity. Per-datacentre configs
# (vSphere, Proxmox, Vault) are environment-specific and stay out of the catalog.
test_provider_configs_are_in_cluster_only = lambda {
    _pc = c.get("machinery").providerConfigs
    assert len(_pc) == 3
    assert all x in _pc {
        x.name == "in-cluster" and x.kind == "ClusterProviderConfig"
    }
}

test_byKind_partitions_the_packages = lambda {
    _p = c.get("machinery")
    _sum = len(c.byKind(_p, "Provider")) + len(c.byKind(_p, "Function")) + len(c.byKind(_p, "Configuration"))
    assert _sum == len(_p.packages), "every package has one of the three kinds"
}

test_get_rejects_an_unknown_profile = lambda {
    assert "machinery" in c.names
    assert len(c.names) == len(c.catalog)
}

# A management cluster must be able to build FURTHER management clusters — that
# is what makes the seed disposable rather than load-bearing forever. It needs
# cluster >=v0.4.0 (spec.managementPlaneEnabled) and management-plane behind it.
#
# UNTERGRENZE, KEIN EXAKTER PIN. Bis 2026-08-20 stand hier
# `endswith(":v0.4.0")`, und das hat die Aussage des Tests verdreht: gepruefte
# Absicht ist "kann Control Planes bauen", nicht "traegt genau diesen Tag". Ein
# Bump des Katalogs liess den Test rot werden, obwohl die Faehigkeit erhalten
# blieb — ein Test, der beim Richtigmachen bricht, wird irgendwann angepasst
# statt gelesen.
test_the_profile_can_build_control_planes = lambda {
    _p = c.get("machinery")
    _cl = [x for x in _p.packages if x.name.endswith("-cluster")][0]
    _v = [int(n) for n in _cl.package.split(":v")[1].split(".")]
    assert _v[0] > 0 or _v[1] >= 4, "cluster muss >= v0.4.0 sein (spec.managementPlaneEnabled)"
    assert "management-plane" in _cl.pulls
    assert "management-plane" in c.transitive(_p)
}

# Die zweite Untergrenze, und der Grund, warum der Katalog am 2026-08-20
# ueberhaupt angefasst wurde: erst cluster v0.6.0 kennt `harvester` im
# Provider-Enum und erst v0.6.1 das Vault-Paar vault-labda ->
# vault-kubeconfigs-labda. Ein Seed unterhalb davon kann die LabDA-Cluster
# nicht bauen, fuer die er aufgestellt wird (crossplane-configurations#258).
test_the_profile_can_build_in_labda = lambda {
    _p = c.get("machinery")
    _cl = [x for x in _p.packages if x.name.endswith("-cluster")][0]
    _v = [int(n) for n in _cl.package.split(":v")[1].split(".")]
    assert _v[0] > 0 or _v[1] > 6 or (_v[1] == 6 and _v[2] >= 1), "cluster muss >= v0.6.1 sein (vault-labda, harvester)"
}

# harvester-vm gehoert ins Profil, weil das machinery-Playbook es auf jeden
# Machinery-Cluster legt. Fehlte bis 2026-08-20 — der Katalog beschrieb eine
# Machinery, die es so nicht gibt.
test_harvester_is_part_of_a_machinery = lambda {
    _p = c.get("machinery")
    _hv = [x for x in _p.packages if x.name.endswith("-harvester-vm")]
    assert len(_hv) == 1, "harvester-vm fehlt im machinery-Profil"
    # Kein providerCrd: rendert ueber provider-kubernetes, registriert keinen
    # eigenen Provider. Ein gesetztes Feld hier waere ein Wartefehler beim
    # Bootstrap.
    assert not _hv[0]?.providerCrd
}
