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

# Every dependsOn must name a component that exists in the SAME app — a typo
# here would otherwise surface as a Kustomization stuck in DependencyNotReady
# on a live cluster, which is a slow and confusing way to find it.
test_dependson_targets_exist = lambda {
    assert all _n, app in c.catalog {
        all comp in app.components {
            all dep in comp.dependsOn {
                dep in [x.name for x in app.components]
            }
        }
    }, "a dependsOn entry names a component that does not exist in its app"
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
