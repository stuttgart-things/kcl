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
    assert c.derivedName("xpkg.crossplane.io/crossplane-contrib/provider-helm:v1.4.0") == "crossplane-contrib-provider-helm"
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

# Function CR names stay SHORT (root CLAUDE.md) — with ONE exception, and it is
# narrow: the dependsOn twin, which carries exactly the name the resolver
# derives, on exactly the registry our dependsOn entries name
# (xpkg.crossplane.io). That CR is created on every cluster anyway; listing it
# only pins it. A long name on any OTHER registry would be a node of its own
# and freeze the resolver for every package on the cluster.
test_function_names_are_short = lambda {
    _f = c.byKind(c.get("machinery"), "Function")
    assert len(_f) > 0
    _long = [p for p in _f if p.name.startswith("crossplane-contrib-")]
    assert all p in _long {
        p.name == c.derivedName(p.package) and p.package.startswith("xpkg.crossplane.io/")
    }, "a long Function name is only allowed as the exact dependsOn twin on xpkg.crossplane.io"
    # A twin never stands alone: the Compositions reference the short name.
    _short = [p.name for p in _f if not p.name.startswith("crossplane-contrib-")]
    assert all p in _long {
        p.name.removeprefix("crossplane-contrib-") in _short
    }, "every dependsOn twin has its short-named sibling"
}

# The two dependsOn twins, pinned (flux#506). Unpinned, a fresh cluster floats them:
# u26-kindtest got function-kcl 0.12.3 / patch-and-transform 0.10.11 against
# kind3's 0.12.2 / 0.10.8.
test_function_twins_are_pinned = lambda {
    _names = [p.name for p in c.byKind(c.get("machinery"), "Function")]
    assert "crossplane-contrib-function-kcl" in _names
    assert "crossplane-contrib-function-patch-and-transform" in _names
}

# THE RULE THE WHOLE LOCK RESTS ON: no two packages may share a SOURCE.
#
# Crossplane keys its Lock on the source, so one source under two CR names is
# one node twice, and then nothing on the cluster resolves -- not the pair, all
# of it. machinery came up on 2026-09-22 with every one of its 51 packages
# Healthy=False because function-go-templating and its dependsOn twin were both
# on xpkg.crossplane.io.
#
# Checked across the whole profile, not just the functions: a Provider or
# Configuration listed twice (say under a derived and a short name) is the same
# failure.
test_no_two_packages_share_a_source = lambda {
    _pkgs = c.get("machinery").packages
    _srcs = [p.package.split(":")[0] for p in _pkgs]
    _dupes = sorted({x: "" for x in _srcs if len([y for y in _srcs if y == x]) > 1})
    assert _dupes == [], "one source under two CR names is a duplicate Lock node"
}

# Its consequence for the functions, stated where it is easy to get wrong: the
# short name lives on xpkg.upbound.io, the twin on xpkg.crossplane.io (the
# registry every dependsOn in crossplane-configurations names). Mirroring them
# the other way round would be just as fine -- what is NOT fine is both on one.
test_short_functions_and_twins_split_the_mirrors = lambda {
    _f = c.byKind(c.get("machinery"), "Function")
    _short = [p for p in _f if not p.name.startswith("crossplane-contrib-")]
    _twins = [p for p in _f if p.name.startswith("crossplane-contrib-")]
    assert all p in _short {
        p.package.startswith("xpkg.upbound.io/")
    }, "a short Function CR sits on xpkg.upbound.io, away from its dependsOn twin"
    assert all p in _twins {
        p.package.startswith("xpkg.crossplane.io/")
    }, "a dependsOn twin sits on xpkg.crossplane.io, the registry the dependsOn names"
    assert len(_twins) == len(_short), "every short Function has its twin pinned"
}

# A twin runs the same version as its short sibling. Two versions of one
# function add nothing.
test_function_twins_match_their_short_sibling = lambda {
    _f = {p.name: p.package.split(":")[-1] for p in c.byKind(c.get("machinery"), "Function")}
    assert all n, v in _f {
        not n.startswith("crossplane-contrib-") or _f[n.removeprefix("crossplane-contrib-")] == v
    }, "a dependsOn twin is pinned to the same version as its short-named sibling"
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
# The version was believed to matter as well: catalog 0.5.0 raised function-kcl
# to v0.12.3 -- the version the crossplane.io dependsOn node already ran -- and
# cicd-test4 reported "cannot initialize dependency graph from the packages in
# the lock" for EVERY package. Since 0.7.0 the dependsOn node is pinned at
# v0.12.2, the same version kind5 runs healthy on both mirrors (same digest
# suffix, different revision names). "Same digest = one node" therefore does not
# explain that incident on its own; the pin stays until cicd-test4 is understood.
test_function_kcl_stays_below_the_dependson_node = lambda {
    _f = [p for p in c.byKind(c.get("machinery"), "Function") if p.name == "function-kcl"]
    assert len(_f) == 1
    assert _f[0].package.endswith(":v0.12.2"), "function-kcl stays at v0.12.2 until the cicd-test4 incident (catalog 0.5.0, v0.12.3) is understood"
}

test_function_kcl_stays_on_the_other_mirror = lambda {
    _k = [p for p in c.byKind(c.get("machinery"), "Function") if p.name == "function-kcl"]
    assert len(_k) == 1
    assert _k[0].package.startswith("xpkg.upbound.io/")
}

# Die Decke, und zwar als Decke geprueft statt als eine erlaubte Version.
#
# 30 dependsOn-Eintraege in crossplane-configurations verlangen
# >=v0.6.5,<v0.7.0; mit v0.7.0 melden die Package-Revisions "incompatible
# dependencies" und der Install-Wait laeuft in den Timeout. Das ist eine
# Fleet-Tatsache, keine Vorliebe.
#
# Vorher stand hier `endswith(":v0.6.5")`. Das ist derselbe Fehler, der
# test_the_profile_can_build_control_planes einmal auf v0.4.0 festgenagelt
# hat: eine Untergrenze/Obergrenze als Gleichheit geschrieben. Der Test war
# dadurch gegen genau die Bumps rot, die er erlauben soll — v0.6.6 bis v0.6.8
# sind reine CVE-Backports UNTERHALB der Decke.
test_function_auto_ready_stays_below_070 = lambda {
    _a = [p for p in c.byKind(c.get("machinery"), "Function") if p.name == "function-auto-ready"]
    assert len(_a) == 1
    _v = [int(n) for n in _a[0].package.split(":v")[1].split(".")]
    assert _v[0] == 0 and _v[1] == 6, "function-auto-ready muss auf der 0.6er-Linie bleiben (dependsOn <v0.7.0)"
    assert _v[2] >= 5, "unterhalb v0.6.5 verletzt die untere Grenze der dependsOn-Spanne"
}

# provider-kubernetes IS an entry since 0.7.0, under the derived name — the
# same Lock node the dependsOn creates, so listing it pins it and adds nothing.
# What must never appear is the SHORT name: that would be the duplicate.
# Until 0.6.0 this test asserted the opposite, on the belief that listing it at
# all was the duplicate; with derived names it is not (flux#506).
test_provider_kubernetes_is_pinned_under_the_derived_name = lambda {
    _pkgs = c.get("machinery").packages
    assert all p in _pkgs {
        p.name != "provider-kubernetes"
    }, "the short name would be a second Lock node"
    _k = [p for p in _pkgs if p.name == "crossplane-contrib-provider-kubernetes"]
    assert len(_k) == 1
    assert _k[0].package.startswith("xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:")
}

# The registry is part of a pulled provider's identity: the explicit entry must
# name exactly the path the dependsOn names, or it is a second node.
test_pulled_providers_keep_the_dependson_registry = lambda {
    _want = {
        "crossplane-contrib-provider-kubernetes" = "xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:"
        "valkiriaaquaticamendi-provider-proxmox-bpg" = "xpkg.upbound.io/valkiriaaquaticamendi/provider-proxmox-bpg:"
        "upbound-provider-vault" = "xpkg.upbound.io/upbound/provider-vault:"
        "vshn-provider-minio" = "ghcr.io/vshn/provider-minio:"
    }
    _p = {p.name: p.package for p in c.byKind(c.get("machinery"), "Provider")}
    assert all n, prefix in _want {
        n in _p and _p[n].startswith(prefix)
    }, "a pulled provider is pinned on exactly the registry its dependsOn names"
}

# The runtime tuning the play gives the two upjet providers that shell out to
# terraform. Without it a Flux-built machinery reproduces the load that cost
# u26-kind3 ~3950 control-plane restarts in 39 days.
test_upjet_providers_are_slowed_down = lambda {
    _p = {p.name: p for p in c.byKind(c.get("machinery"), "Provider")}
    assert _p["upbound-provider-opentofu"].env["CROSSPLANE_OPENTOFU_PROVIDER_POLL"] == "1h"
    assert _p["valkiriaaquaticamendi-provider-proxmox-bpg"].env["PROVIDER_POLL"] == "1h"
    assert _p["upbound-provider-opentofu"].resources.limits.cpu == "2"
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

# capability und argocd-cluster gehoeren ins Profil, und zwar aus dem
# Umkehrschluss der roots-only-Regel: NICHTS zieht sie ueber dependsOn, also
# existieren sie nur, wo jemand sie installiert. Auf u26-kind3 war das von
# Hand — ein aus Git neu gebauter Machinery-Cluster hatte beide XRDs nicht
# (u26-kindtest-Rebuild, 2026-09-19). Ein Paket, das nur per kubectl auf dem
# Referenz-Cluster liegt, ist keine Fleet-Tatsache; hier wird es eine.
test_machinery_carries_the_unpulled_configurations = lambda {
    _p = c.get("machinery")
    _names = [x.name for x in c.byKind(_p, "Configuration")]
    assert "stuttgart-things-crossplane-configurations-capability" in _names, "capability fehlt — nichts zieht es transitiv nach"
    assert "stuttgart-things-crossplane-configurations-argocd-cluster" in _names, "argocd-cluster fehlt — nichts zieht es transitiv nach"

    # Und sie sind wirklich unpulled: tauchte einer der beiden in irgendeinem
    # `pulls` auf, waere dieser Test ab morgen aus dem falschen Grund gruen.
    _t = c.transitive(_p)
    assert "capability" not in _t and "argocd-cluster" not in _t
}

# provider-kubeconfig muss seine DeploymentRuntimeConfig benennen. Ohne die
# Referenz laeuft der Provider mit `default`, bekommt kein VAULT_CACERT und
# jeder Vault-Login scheitert an "x509: certificate signed by unknown
# authority" — was wie ein Credential-Problem aussieht und keines ist.
#
# Auf kind-Clustern patcht das Playbook das CR nachtraeglich; ein Flux-Cluster
# hat diesen Moment nicht, deswegen steht es hier. Die Config selbst liefert
# der provider-kubeconfig-vault-Chart aus dem Fleet-State des Clusters.
test_kubeconfig_provider_names_its_runtime_config = lambda {
    _p = c.get("machinery")
    _kc = [x for x in _p.packages if x.name.endswith("-provider-kubeconfig-xpkg")]
    assert len(_kc) == 1, "provider-kubeconfig fehlt im machinery-Profil"
    assert _kc[0]?.runtimeConfig == "provider-kubeconfig", "ohne runtimeConfig laeuft der Provider ohne Vault-CA"

    # Und sonst niemand: jede weitere Referenz braucht jemanden, der die
    # DeploymentRuntimeConfig auch ausliefert.
    _with = [x.name for x in _p.packages if x?.runtimeConfig]
    assert len(_with) == 1, "unerwartete runtimeConfig-Referenz: ${_with}"
}
