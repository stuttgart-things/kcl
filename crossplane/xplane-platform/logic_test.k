# Unit tests for the platform logic. `kcl test`.
# These are the rules that would otherwise only be observable on a live cluster.
import .logic as l

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

test_headlamp_missing_vars_detected = lambda {
    assert len(l.missingSubstitutions({
        apps = {
            headlamp = {}
        }
    })) == 3
}
