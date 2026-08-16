# Unit tests for the platform logic. `kcl test`.
# These are the rules that would otherwise only be observable on a live cluster.
import .logic as l
import xplane_flux_catalog as cat

# template-execution requires GITHUB_TOKEN / BACKSTAGE_AUTH_TOKEN / REDIS_PASSWORD,
# so a bare {dapr = {}} is now correctly rejected — supply them via substituteFrom.
_dapr = {
    apps = {
        dapr = {
            components = {
                "template-execution" = {
                    substituteFrom = [{kind = "Secret", name = "dapr-vars"}]
                }
            }
        }
    }
}

test_shared_derives_refs_from_clustername = lambda {
    s = l.resolveShared({clusterName = "kind1"})
    assert s.helmProviderConfigRef == "kind1-helm"
    assert s.kubernetesProviderConfigRef == "kind1-kubernetes"
    assert s.namespace == "flux-system"
}

# Unresolved fields must be absent, not "" — a consumer testing
# `if shared.clusterName` must not get a value that was never resolved.
test_shared_omits_unresolved_clustername = lambda {
    s = l.resolveShared({helmProviderConfigRef = "h", kubernetesProviderConfigRef = "k"})
    assert "clusterName" not in s
}

test_explicit_refs_win = lambda {
    s = l.resolveShared({clusterName = "kind1", helmProviderConfigRef = "custom"})
    assert s.helmProviderConfigRef == "custom"
}

# The point of the whole module: one toggle produces the source AND the app.
test_enabled_app_yields_source_and_entries = lambda {
    src = l.appSources(_dapr)
    assert len(src) == 1
    assert src[0].name == "dapr"
    assert src[0].url == "oci://ghcr.io/stuttgart-things/flux/apps/dapr"
    assert src[0].ref == "v1.18.1"
    e = l.appEntries(_dapr)
    assert len(e) == 2
    assert e[0].sourceRef.name == "dapr", "app entry must reference the source the same toggle created"
}

test_disabled_app_yields_nothing = lambda {
    spec = {
        apps = {
            dapr = {enabled = False}
        }
    }
    assert len(l.appSources(spec)) == 0
    assert len(l.appEntries(spec)) == 0
}

test_version_override = lambda {
    assert l.appSources({
        apps = {
            dapr = {version = "v1.17.0"}
        }
    })[0].ref == "v1.17.0"
}

# dependsOn must be rewritten to the emitted names, or Flux looks for a
# Kustomization called 'control-plane' that does not exist.
test_dependson_is_rewritten_to_emitted_names = lambda {
    e = [x for x in l.appEntries(_dapr) if x.name == "dapr-template-execution"][0]
    assert e.dependsOn == [{name = "dapr-control-plane"}]
}

test_helmrelease_timeout_carried_from_catalog = lambda {
    e = [x for x in l.appEntries(_dapr) if x.name == "dapr-control-plane"][0]
    assert e.timeout == "15m"
}

test_substitute_merges_app_and_component = lambda {
    spec = {
        apps = {
            dapr = {
                substitute = {DAPR_NAMESPACE = "dapr-system"}
                components = {
                    "template-execution" = {
                        substitute = {FLUX_SOURCE_API_VERSION = "v1"}
                    }
                }
            }
        }
    }
    e = [x for x in l.appEntries(spec) if x.name == "dapr-template-execution"][0]
    assert e.substitute.DAPR_NAMESPACE == "dapr-system"
    assert e.substitute.FLUX_SOURCE_API_VERSION == "v1"
}

# substituteFrom is component-scoped on purpose: it resolves at BUILD time and a
# missing Secret fails the build, so applying an app-level one to every
# component would break components that do not need it.
test_substitutefrom_is_component_scoped = lambda {
    spec = {
        apps = {
            dapr = {
                components = {
                    "template-execution" = {
                        substituteFrom = [{kind = "Secret", name = "dapr-vars"}]
                    }
                }
            }
        }
    }
    entries = {x.name: x for x in l.appEntries(spec)}
    assert "substituteFrom" in entries["dapr-template-execution"]
    assert "substituteFrom" not in entries["dapr-control-plane"]
}

test_apps_without_fluxinit_is_rejected = lambda {
    assert l.validate(_dapr)
    assert l.validate({
        fluxInit = {enabled = False}
    })
}

# A component whose required vars are neither in substitute nor covered by a
# substituteFrom must be rejected — Flux would substitute empty strings and
# deploy something broken without ever failing.
test_missing_required_substitutions_detected = lambda {
    m = l.missingSubstitutions({
        apps = {
            dapr = {}
        }
    })
    assert len(m) == 3, "dapr template-execution has 3 required vars"
    assert "dapr-template-execution: GITHUB_TOKEN" in m
}

test_substitutefrom_satisfies_required = lambda {
    assert len(l.missingSubstitutions(_dapr)) == 0
}

test_explicit_substitute_satisfies_required = lambda {
    spec = {
        apps = {
            headlamp = {
                substitute = {DOMAIN = "d", HOSTNAME = "h", GATEWAY_NAME = "g"}
            }
        }
    }
    assert len(l.missingSubstitutions(spec)) == 0
}

# Three variables, but not three of the same kind. HOSTNAME and GATEWAY_NAME
# are decisions nothing can look up — fatal. DOMAIN is discoverable, so a bare
# enable is rejected for two, not three.
test_headlamp_missing_vars_detected = lambda {
    _spec = {
        apps = {
            headlamp = {}
        }
    }
    assert len(l.missingSubstitutions(_spec)) == 2
    assert l.pendingSubstitutions(_spec) == ["headlamp-app: DOMAIN"]
}

# --- cross-artifact dependsOn -------------------------------------------------

# trust-manager cannot reconcile before cert-manager's CRDs exist; the reference
# must resolve to cert-manager's emitted Kustomization name, not trust-manager's.
test_cross_artifact_dependson_resolves = lambda {
    e = [x for x in l.appEntries({
        apps = {"trust-manager" = {}, "cert-manager" = {}}
    }) if x.name == "trust-manager-install"][0]
    assert e.dependsOn == [{name = "cert-manager-install"}]
}

# Rejected, not auto-enabled: a toggle that silently installs artifacts you did
# not list gets confusing with transitive chains.
test_missing_dependency_app_is_reported = lambda {
    p = l.depProblems({
        apps = {
            "trust-manager" = {}
        }
    })
    assert len(p) == 1
    assert "add it to spec.apps" in p[0], "the message must name the fix"
    assert "cert-manager" in p[0]
}

test_disabled_dependency_component_is_reported = lambda {
    p = l.depProblems({
        apps = {"trust-manager" = {}, "cert-manager" = {
            components = {
                install = {enabled = False}
            }
        }}
    })
    assert len([x for x in p if "is disabled" in x]) > 0
}

test_satisfied_dependency_has_no_problems = lambda {
    assert len(l.depProblems({
        apps = {"trust-manager" = {}, "cert-manager" = {}}
    })) == 0
}

# --- optional components ------------------------------------------------------

# cert-manager's selfsigned issuer needs a domain; requiring it just to install
# cert-manager would make the base app unusable.
test_optional_component_not_emitted_by_default = lambda {
    names = [e.name for e in l.appEntries({
        apps = {
            "cert-manager" = {}
        }
    })]
    assert "cert-manager-install" in names
    assert "cert-manager-selfsigned" not in names
}

test_optional_component_emitted_when_enabled = lambda {
    spec = {
        apps = {
            "cert-manager" = {
                components = {
                    selfsigned = {enabled = True, substitute = {CERT_MANAGER_SELFSIGNED_DOMAIN = "example.com"}}
                }
            }
        }
    }
    assert "cert-manager-selfsigned" in [e.name for e in l.appEntries(spec)]
}

# An optional component that is off must not have its required vars demanded.
test_optional_component_vars_not_required_when_off = lambda {
    assert len(l.missingSubstitutions({
        apps = {
            "cert-manager" = {}
        }
    })) == 0
}

test_cni_is_opt_in = lambda {
    # Inverse default from every other component: most clusters already have a
    # CNI and a second one breaks them.
    assert l.cniEnabled({}) == False
    assert l.cniEnabled({
        cni = {}
    }) == False
    assert l.cniEnabled({
        cni = {enabled = True}
    }) == True
    assert l.cniEnabled({
        cni = {enabled = False}
    }) == False
}

test_gate_holds_children_until_ready = lambda {
    assert l.gateOpen(False, False) == False
    assert l.gateOpen(True, False) == True
}

test_gate_is_one_way = lambda {
    # A CNI blipping not-Ready mid chart-upgrade must NOT drop an existing child
    # — not emitting it is what makes Crossplane delete it.
    assert l.gateOpen(False, True) == True
}

test_cilium_and_ipreservation_are_opt_in = lambda {
    assert l.ciliumEnabled({}) == False
    assert l.ipReservationEnabled({}) == False
    assert l.ciliumEnabled({
        cilium = {enabled = True}
    }) == True
    assert l.ipReservationEnabled({
        ipReservation = {enabled = True}
    }) == True
    assert l.ciliumEnabled({
        cilium = {enabled = False}
    }) == False
}

test_vault_issuer_is_opt_in = lambda {
    assert l.vaultIssuerEnabled({}) == False
    assert l.vaultIssuerEnabled({
        vaultIssuer = {enabled = True}
    }) == True
    assert l.vaultIssuerEnabled({
        vaultIssuer = {enabled = False}
    }) == False
}

test_vault_issuer_still_opt_in = lambda {
    assert l.vaultIssuerEnabled({
        vaultIssuer = {enabled = True}
    }) == True
}

# openebs reaches the platform, and reaches it with an EMPTY spec. The catalog
# entry has no required substitutions and no dependsOn, so `apps.openebs.enabled`
# alone must render both halves — the flux-init source and the flux-apps
# Kustomization — with nothing else supplied. Asserted here rather than only in
# the catalog, because the app -> (source, kustomization) fan-out is this
# module's job and a missing source is invisible until Flux reports
# ArtifactFailed on the target cluster.
test_openebs_renders_from_a_bare_enable = lambda {
    _spec = {clusterName = "c", apps = {
        openebs = {enabled = True}
    }}
    _srcs = l.appSources(_spec)
    _named = [s for s in _srcs if s.name == "openebs"]
    assert len(_named) == 1
    assert _named[0].url == "oci://ghcr.io/stuttgart-things/flux/infra/openebs"
    # The floor that can say no to Loki/MinIO/Alloy — see the catalog entry.
    assert _named[0].ref == "v1.19.1"
}

# The catalog's cilium entry, reached through spec.apps — NOT spec.cilium.
#
# The two are different paths to Cilium and only this one is used by the
# Gateway work (crossplane-configurations#248): spec.cilium composes a Cilium
# XR from the bootstrap/cilium Configuration, which was never published;
# apps.cilium reconciles the flux/infra/cilium artifact's lb + gateway. Naming
# them apart here so the next reader does not assume one test covers both.
test_apps_cilium_renders_from_the_catalog = lambda {
    _spec = {clusterName = "c", apps = {
        cilium = {enabled = True, substitute = {
            CILIUM_LB_IP_START = "10.31.102.5"
            CILIUM_LB_IP_STOP = "10.31.102.5"
            CILIUM_GATEWAY_DOMAIN = "u26-rke2-1.sthings-vsphere.labul.sva.de"
            CILIUM_GATEWAY_TLS_SECRET = "gateway-tls"
        }}
    }}
    _named = [s for s in l.appSources(_spec) if s.name == "cilium"]
    assert len(_named) == 1
    assert _named[0].url == "oci://ghcr.io/stuttgart-things/flux/infra/cilium"
    assert _named[0].ref == "v1.18.1"
    assert len(l.missingSubstitutions(_spec)) == 0
}

# A bare enable must be REJECTED, unlike openebs above. All four of cilium's
# variables lack a manifest default, and Flux substitutes an empty string
# instead of failing — an IP pool with blank bounds and a Gateway with a blank
# hostname both apply cleanly and do nothing, so the cluster would look healthy.
test_apps_cilium_bare_enable_is_rejected = lambda {
    _m = l.missingSubstitutions({
        apps = {
            cilium = {enabled = True}
        }
    })
    assert _m == ["cilium-config: CILIUM_GATEWAY_TLS_SECRET"], "the one nothing can look up"
    assert len(l.pendingSubstitutions({
        apps = {
            cilium = {enabled = True}
        }
    })) == 3, "the other three wait for the reservation"
}

# The wildcard the clusterbook reservation publishes is not the domain — the
# leading `*.` belongs to the DNS record. Stripping it once here is what keeps
# every consumer from doing the same string surgery.
test_cluster_domain_strips_the_wildcard = lambda {
    assert l.clusterDomain("*.u26-rke2-1.sthings-vsphere.labul.sva.de") == "u26-rke2-1.sthings-vsphere.labul.sva.de"
}

# Not every reservation carries a wildcard: `spec.ip` skips DNS entirely, and a
# non-wildcard record would already be usable. Both must pass through untouched
# rather than losing their first two characters.
test_cluster_domain_passes_through_non_wildcards = lambda {
    assert l.clusterDomain("") == ""
    assert l.clusterDomain("gw.example.com") == "gw.example.com"
}

_disc = {
    ipReservation = {domain = "u26-rke2-1.sthings-vsphere.labul.sva.de", ipAddresses = ["10.31.102.8"], zone = "sthings-vsphere.labul.sva.de"}
}

# The two path shapes the catalog uses, and every way a path can read nothing.
# Anything unreadable must be "" so the caller leaves the variable UNSET —
# a blank substituted value is what requiredSubstitutions exists to prevent.
test_resolve_source_reads_the_two_shapes = lambda {
    assert l.resolveSource(_disc, "ipReservation.domain") == "u26-rke2-1.sthings-vsphere.labul.sva.de"
    assert l.resolveSource(_disc, "ipReservation.ipAddresses[0]") == "10.31.102.8"
}

test_resolve_source_is_empty_when_unreadable = lambda {
    assert l.resolveSource(_disc, "ipReservation.ipAddresses[3]") == "", "index past the end"
    assert l.resolveSource({}, "ipReservation.domain") == "", "nothing discovered yet"
    assert l.resolveSource(_disc, "nope.field") == "", "unknown group"
    assert l.resolveSource(_disc, "a.b.c") == "", "deeper than the supported two segments"
}

# cilium's three resolve; the fourth has no source and must stay absent, so the
# XR still has to name the Secret a certificate gets issued into.
test_discovered_substitutions_fill_only_facts = lambda {
    _comp = cat.get("cilium").components[0]
    _got = l.discoveredSubstitutions(_comp, _disc)
    assert _got["CILIUM_GATEWAY_DOMAIN"] == "u26-rke2-1.sthings-vsphere.labul.sva.de"
    assert _got["CILIUM_LB_IP_START"] == "10.31.102.8"
    assert _got["CILIUM_LB_IP_STOP"] == "10.31.102.8"
    assert "CILIUM_GATEWAY_TLS_SECRET" not in _got
}

# Discovery turns three of the four from missing into supplied. The TLS Secret
# stays missing — it is a decision, not a fact.
test_discovery_satisfies_required_substitutions = lambda {
    _spec = {clusterName = "c", apps = {
        cilium = {enabled = True}
    }}
    assert len(l.pendingSubstitutions(_spec)) == 3, "nothing discovered yet: three still waiting"
    assert len(l.pendingSubstitutions(_spec, _disc)) == 0, "discovery clears all three"
    _m = l.missingSubstitutions(_spec, _disc)
    assert _m == ["cilium-config: CILIUM_GATEWAY_TLS_SECRET"], "only the decision is left"
}

# An explicit value always wins, so a cluster can break out of what was found.
test_explicit_substitute_beats_discovery = lambda {
    _spec = {clusterName = "c", apps = {
        cilium = {enabled = True, substitute = {
            CILIUM_GATEWAY_DOMAIN = "override.example.com"
            CILIUM_GATEWAY_TLS_SECRET = "tls"
        }}
    }}
    _k = [k for k in l.appEntries(_spec, _disc) if k.name == "cilium-config"][0]
    assert _k.substitute["CILIUM_GATEWAY_DOMAIN"] == "override.example.com"
    assert _k.substitute["CILIUM_LB_IP_START"] == "10.31.102.8", "undisputed values still come from discovery"
}

# Opt-in AND a discovered domain. Both halves matter, and the second is easy to
# lose to operator precedence: `enabled or False and domain != ""` parses as
# `enabled or (False and ...)`, which drops the domain check entirely.
test_wildcard_cert_needs_enable_and_domain = lambda {
    _on = {
        vaultIssuer = {
            wildcardCertificate = {enabled = True}
        }
    }
    assert l.wildcardCertEnabled(_on, "u26.example.com")
    assert not l.wildcardCertEnabled(_on, ""), "no domain discovered yet"
    assert not l.wildcardCertEnabled({
        vaultIssuer = {}
    }, "u26.example.com"), "not opted in"
    assert not l.wildcardCertEnabled({}, "u26.example.com"), "no vaultIssuer at all"
}

# headlamp's DOMAIN became discoverable in catalog 0.7.0. Enabling it now needs
# only the two values that are decisions — which name it answers on, and which
# Gateway it attaches to.
test_apps_headlamp_discovers_its_domain = lambda {
    _d = {
        ipReservation = {domain = "u26-rke2-1.sthings-vsphere.labul.sva.de", ipAddresses = ["10.31.102.8"], zone = "z"}
    }
    _spec = {clusterName = "c", apps = {
        headlamp = {enabled = True, substitute = {
            HOSTNAME = "headlamp"
            GATEWAY_NAME = "cilium-gateway"
        }}
    }}
    assert len(l.missingSubstitutions(_spec, _d)) == 0, "DOMAIN comes from the status"
    assert l.pendingSubstitutions(_spec) == ["headlamp-app: DOMAIN"], "and is still awaited when nothing was discovered"
    _k = [k for k in l.appEntries(_spec, _d) if k.name == "headlamp-app"][0]
    assert _k.substitute["DOMAIN"] == "u26-rke2-1.sthings-vsphere.labul.sva.de"
}

test_apps_machinery_discovers_its_domain = lambda {
    _d = {
        ipReservation = {domain = "u26-rke2-1.sthings-vsphere.labul.sva.de", ipAddresses = ["10.31.102.8"], zone = "z"}
    }
    _spec = {clusterName = "c", apps = {
        machinery = {enabled = True, substitute = {
            GATEWAY_NAME = "cilium-gateway"
            MACHINERY_VERSION = "v1.18.1"
        }}
    }}
    assert len(l.missingSubstitutions(_spec, _d)) == 0, "DOMAIN comes from the status"
    _k = [k for k in l.appEntries(_spec, _d) if k.name == "machinery-app"][0]
    assert _k.substitute["DOMAIN"] == "u26-rke2-1.sthings-vsphere.labul.sva.de"
}

test_apps_machinery_costs_one_typed_value = lambda {
    # stuttgart-things/flux#193 fixed the artifact default (it read `1.13.4`
    # while the published tags read `v1.13.4`, so the OCIRepository never
    # resolved), and catalog 0.9.0 dropped MACHINERY_VERSION from the required
    # list. What remains is GATEWAY_NAME — a decision, not a fact, so nothing
    # can discover it.
    _d = {
        ipReservation = {domain = "u26-rke2-1.sthings-vsphere.labul.sva.de", ipAddresses = [], zone = "z"}
    }
    _withGateway = {clusterName = "c", apps = {
        machinery = {enabled = True, substitute = {GATEWAY_NAME = "cilium-gateway"}}
    }}
    assert len(l.missingSubstitutions(_withGateway, _d)) == 0, "the version is no longer typed by hand"

    _bare = {clusterName = "c", apps = {
        machinery = {enabled = True}
    }}
    _missing = l.missingSubstitutions(_bare, _d)
    assert len(_missing) == 1, "the Gateway choice stays required"
    assert "GATEWAY_NAME" in ", ".join(_missing)
}

# The resolver grew from two segments to four when the Vault mount a cluster
# created became discoverable. The old shapes must keep working exactly, and the
# new depth must fail the same way — absent, never truncated.
test_resolve_source_walks_four_segments = lambda {
    _d = {
        vaultIssuer = {
            auths = {
                eso = {mountPath = "mgmt-test1-eso", role = "eso"}
            }
        }
    }
    assert l.resolveSource(_d, "vaultIssuer.auths.eso.mountPath") == "mgmt-test1-eso"
    assert l.resolveSource(_d, "vaultIssuer.auths.eso.role") == "eso"
}

# A path that stops short lands on a dict. Returning str(dict) would substitute
# a rendered map into a Vault mount path — worse than not resolving, because it
# looks like a value. Empty is what lets requiredSubstitutions reject it by name.
test_resolve_source_refuses_a_partial_path = lambda {
    _d = {
        vaultIssuer = {
            auths = {
                eso = {mountPath = "m"}
            }
        }
    }
    assert l.resolveSource(_d, "vaultIssuer.auths") == ""
    assert l.resolveSource(_d, "vaultIssuer.auths.eso") == ""
}

# Deeper than the bound reads as absent rather than as a truncated prefix. A
# prefix would be a plausible-looking wrong value, which is the one outcome
# worse than not resolving.
test_resolve_source_rejects_beyond_the_bound = lambda {
    _d = {
        a = {
            b = {
                c = {
                    d = {e = "too deep"}
                }
            }
        }
    }
    assert l.resolveSource(_d, "a.b.c.d.e") == ""
}

# A missing auth resolves to nothing, not to another auth's mount. This is the
# case that matters on a cluster whose vaultIssuer has not created the ESO auth
# yet: the variable stays unset and the app is rejected by name.
test_resolve_source_missing_auth_is_empty = lambda {
    _d = {
        vaultIssuer = {
            auths = {
                certmanager = {mountPath = "mgmt-certmanager"}
            }
        }
    }
    assert l.resolveSource(_d, "vaultIssuer.auths.eso.mountPath") == ""
}

# --- deferral instead of abort (crossplane-configurations#277) -----------------

# The deadlock this replaced: enabling the eso auth and the app in ONE step made
# the render abort, so the Composition never emitted the VaultK8sAuth the app
# was waiting for — and every unrelated component stopped reconciling with it.
# Nothing about that state converges; only a second, manual apply escaped it.
_esoSpec = {clusterName = "c", apps = {
    "external-secrets" = {
        enabled = True
        components = {
            "cluster-store-vault" = {enabled = True, substitute = {
                VAULT_CSS_NAME = "vault"
                VAULT_KV_PATH = "clusters"
                VAULT_K8S_AUTH_SA_NAME = "eso"
            }}
        }
    }
}}

test_pending_component_does_not_abort_the_render = lambda {
    assert l.missingSubstitutions(_esoSpec) == [], "nothing here is unsuppliable"
    assert l.validate(_esoSpec), "so the render proceeds"
    assert len(l.pendingSubstitutions(_esoSpec)) == 2, "mount path and role are awaited"
}

# Held back ALONE. The operator must install on this very reconcile — the store
# it is waiting for is a CRD that operator owns.
test_pending_component_is_held_back_alone = lambda {
    _names = [e.name for e in l.appEntries(_esoSpec)]
    assert "external-secrets-install" in _names, "the operator still deploys"
    assert "external-secrets-cluster-store-vault" not in _names, "the store waits"
}

# And released once the auth this same Composition creates lands in the status.
test_pending_component_is_released_by_discovery = lambda {
    _d = {
        vaultIssuer = {
            auths = {
                eso = {mountPath = "c-eso", role = "eso"}
            }
        }
    }
    assert l.pendingSubstitutions(_esoSpec, _d) == []
    _k = [e for e in l.appEntries(_esoSpec, _d) if e.name == "external-secrets-cluster-store-vault"][0]
    assert _k.substitute["VAULT_K8S_AUTH_MOUNT_PATH"] == "c-eso", "discovered, not typed"
}

# A variable nothing declares a source for stays fatal. Deferring THAT would
# swap a loud failure for a component that silently never appears.
test_unsuppliable_variable_is_still_fatal = lambda {
    assert len(l.missingSubstitutions({
        apps = {
            "nfs-csi" = {enabled = True}
        }
    })) == 2
    assert l.pendingSubstitutions({
        apps = {
            "nfs-csi" = {enabled = True}
        }
    }) == []
}
