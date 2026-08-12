# Unit tests for the catalog. Run with `kcl test`.
# These validate the catalog's own invariants — no Crossplane, no cluster.
import .main as c

test_dapr_is_registered = lambda {
    assert "dapr" in c.catalog
    assert c.catalog.dapr.artifact == "oci://ghcr.io/stuttgart-things/flux/apps/dapr"
}

test_get_returns_app = lambda {
    assert c.get("dapr").defaultVersion == "v1.18.1"
}

# Every dependsOn must resolve to a component that actually exists — either a
# sibling in the same app, or "app:component" in another app. A typo would
# otherwise surface only as a Kustomization stuck in DependencyNotReady on a
# live cluster, which is a slow and confusing way to find it.
_depApp = lambda owner: str, dep: str -> str {
    dep.split(":")[0] if ":" in dep else owner
}
_depComponent = lambda dep: str -> str {
    dep.split(":")[1] if ":" in dep else dep
}

test_dependson_targets_exist = lambda {
    assert all _n, app in c.catalog {
        all comp in app.components {
            all dep in comp.dependsOn {
                _depApp(_n, dep) in c.catalog and _depComponent(dep) in [x.name for x in c.catalog[_depApp(_n, dep)].components]
            }
        }
    }, "a dependsOn entry names a component that does not exist"
}

# The first cross-artifact dependency: trust-manager cannot reconcile before
# cert-manager's CRDs exist.
test_cross_artifact_dependson = lambda {
    tm = c.get("trust-manager").components[0]
    assert tm.dependsOn == ["cert-manager:install"]
    assert "install" in [x.name for x in c.get("cert-manager").components]
}

# Component names must be unique within an app; duplicates would collide on the
# emitted Kustomization name '{app}-{component}'.
test_component_names_unique = lambda {
    assert all _n, app in c.catalog {
        len([x.name for x in app.components]) == len({x.name: "" for x in app.components})
    }, "component names must be unique within an app"
}

# Anything wrapping a HelmRelease needs a raised timeout — the 10m FluxApps
# default was demonstrably too short for dapr's chart install.
test_helmrelease_components_raise_timeout = lambda {
    assert all _n, app in c.catalog {
        all comp in app.components {
            not comp.wrapsHelmRelease or comp.timeout != Undefined
        }
    }, "a component that wraps a HelmRelease must raise its timeout"
}

test_headlamp_is_registered = lambda {
    h = c.get("headlamp")
    assert h.artifact == "oci://ghcr.io/stuttgart-things/flux/apps/headlamp"
    assert len(h.components) == 1
    assert h.components[0].path == "./", "single-component apps reconcile the artifact root"
}

# Vars without a manifest default must be declared, or Flux substitutes an empty
# string and deploys something silently broken.
test_headlamp_declares_required_substitutions = lambda {
    assert c.get("headlamp").components[0].requiredSubstitutions == ["DOMAIN", "HOSTNAME", "GATEWAY_NAME"]
}

# Opt-in extras must not default to enabled: cert-manager's selfsigned issuer
# needs a domain, and requiring it just to install cert-manager would be wrong.
test_optional_components_are_marked = lambda {
    cm = {x.name: x for x in c.get("cert-manager").components}
    assert not cm["install"].optional, "the base install is not optional"
    assert cm["selfsigned"].optional
}

# openebs declares no REQUIRED substitutions — every variable in its manifests
# carries a `${VAR:-default}` fallback.
#
# THAT IS A STATEMENT ABOUT THE CATALOG, NOT ABOUT USAGE, and the distinction
# cost a live debug on u26-rke2-1 (2026-08-12). An XR still has to supply a
# `substitute` block: xplane-flux-apps used to emit `postBuild` only when one
# was present, and kustomize-controller runs its substitution pass only when
# spec.postBuild is non-nil — so a bare enable meant NO substitution at all and
# the fallbacks never applied. `${OPENEBS_NAMESPACE:-openebs}` reached the
# cluster as a literal string and failed namespace validation.
#
# Fixed in xplane-flux-apps 0.2.0, which always emits postBuild. The test name
# stays about the catalog on purpose — it was previously called
# `test_openebs_needs_no_substitutions`, which read as a promise about usage.
test_openebs_declares_no_required_substitutions = lambda {
    _a = c.get("openebs")
    assert len(_a.components) == 1
    assert _a.components[0].requiredSubstitutions == []
    assert _a.components[0].dependsOn == []
    assert _a.components[0].path == "./"
    assert _a.components[0].wrapsHelmRelease
}

# The catalog version is the FLUX ARTIFACT tag, never the openebs chart version
# (which the artifact pins separately as OPENEBS_VERSION, default 4.2.0). v1.19.1
# is the floor because it is the first release that carries flux#192 — before
# it, the artifact had no loki/alloy keys, so raising OPENEBS_VERSION to 4.5.x
# would have silently deployed Loki, MinIO and Alloy with no way to say no.
test_openebs_pins_a_release_that_can_say_no_to_loki = lambda {
    _v = c.get("openebs").defaultVersion
    assert _v.startswith("v")
    assert _v != "v4.2.0"
    assert _v == "v1.19.1"
}
