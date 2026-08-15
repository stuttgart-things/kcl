"""
xplane-management-plane — function-kcl module for the management-plane Configuration.

Turns a cluster into a MANAGEMENT cluster: installs Crossplane on it, then the
packages and provider configs that let it build other clusters. What it installs
comes from xplane-crossplane-catalog, not from this XR — the package set is a
fleet fact and belongs where it can be version-controlled and tested.

  1. helm.m.crossplane.io Release      — the crossplane chart
  2. kubernetes.m.crossplane.io Object — one per Provider / Function / Configuration
  3. kubernetes.m.crossplane.io Object — one per in-cluster ProviderConfig

Render and status happen in a single pass: the module emits the managed
resources AND patches the XR status from `ocds`. On the first reconcile `ocds`
is empty, so status.ready starts False and converges.

This is deliberately NOT part of `platform`. platform answers "what does this
cluster offer"; being a management cluster is a ROLE, and the two have different
lifetimes — a workload cluster's apps change weekly, its control plane does not.

All decision logic lives in logic.k so it is unit-testable without Crossplane;
this file only marshals option("params") in and `items` out.
"""

import .logic as l

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}
_name = _meta?.name or "management-plane"
_xrNs = _meta?.namespace

_valid = l.validate(_spec)

_helmPcr = l.helmRef(_spec)
_k8sPcr = l.kubernetesRef(_spec)
_ns = l.targetNamespace(_spec)
_packages = l.packages(_spec)
_profile = l.profile(_spec)

# --- observed children ------------------------------------------------------
_byName = lambda name: str -> [any] {
    [v.Resource for _, v in _ocds if v?.Resource?.metadata?.name == name]
}
_isReady = lambda res: any -> bool {
    len([c for c in (res?.status?.conditions or []) if c?.type == "Ready" and c?.status == "True"]) > 0
}

_coreName = "{}-crossplane".format(_name)
_coreObs = _byName(_coreName)
_coreReady = len(_coreObs) > 0 and _isReady(_coreObs[0])

_pkgName = lambda p -> str {
    "{}-pkg-{}".format(_name, p.name)
}
_pkgObs = [x for p in _packages for x in _byName(_pkgName(p))]
_pkgReady = len(_pkgObs) == len(_packages) and len([x for x in _pkgObs if _isReady(x)]) == len(_packages)

_pcName = lambda i: int, pc -> str {
    "{}-pc-{}".format(_name, i)
}
_pcObs = [x for i, pc in _profile.providerConfigs for x in _byName(_pcName(i, pc))]

# --- gates ------------------------------------------------------------------
_pkgOpen = l.packagesOpen(_coreReady, len(_pkgObs))
_pcOpen = l.providerConfigsOpen(_pkgReady, len(_pcObs))

# --- 1) Crossplane core -----------------------------------------------------
_core = {
    apiVersion = "helm.m.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = _coreName
        namespace = _xrNs
        annotations = {
            "krm.kcl.dev/composition-resource-name" = _coreName
        }
    }
    spec = {
        forProvider = {
            chart = {
                name = "crossplane"
                repository = "https://charts.crossplane.io/stable"
                version = l.crossplaneVersion(_spec)
            }
            namespace = _ns
            skipCreateNamespace = False
            wait = True
        }
        providerConfigRef = {
            name = _helmPcr
            kind = "ClusterProviderConfig"
        }
    }
}

# --- 2) packages ------------------------------------------------------------
# The CR name comes from the catalog, which derives it the way Crossplane does.
# It is the whole reason this Configuration can be upgraded without the Lock
# collision that #247 describes.
_packageObject = lambda p -> any {
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = _pkgName(p)
            namespace = _xrNs
            annotations = {
                "krm.kcl.dev/composition-resource-name" = _pkgName(p)
                "crossplane.io/uses" = _coreName
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = l.packageApiVersion(p)
                    kind = p.kind
                    metadata = {
                        name = p.name
                    }
                    spec = {
                        package = p.package
                    }
                }
            }
            providerConfigRef = {
                name = _k8sPcr
                kind = "ClusterProviderConfig"
            }
        }
    }
}

# --- 3) in-cluster provider configs ----------------------------------------
_providerConfigObject = lambda i: int, pc -> any {
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = _pcName(i, pc)
            namespace = _xrNs
            annotations = {
                "krm.kcl.dev/composition-resource-name" = _pcName(i, pc)
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = pc.apiVersion
                    kind = pc.kind
                    metadata = {
                        name = pc.name
                    }
                    spec = pc.spec
                }
            }
            providerConfigRef = {
                name = _k8sPcr
                kind = "ClusterProviderConfig"
            }
        }
    }
}

_status = {
    apiVersion = _oxr?.apiVersion
    kind = _oxr?.kind
    metadata = {
        name = _name
        namespace = _xrNs
    }
    status = {
        ready = _coreReady and _pkgReady
        profile = l.profileName(_spec)
        crossplaneVersion = l.crossplaneVersion(_spec)
        components = {
            crossplane = {
                ready = _coreReady
                version = l.crossplaneVersion(_spec)
            }
            packages = {
                total = len(_packages)
                ready = len([x for x in _pkgObs if _isReady(x)])
            }
            providerConfigs = {
                total = len(_profile.providerConfigs)
                emitted = len(_pcObs)
            }
        }
        # What arrives without being installed. Stated because "which packages
        # are on this cluster" cannot be answered from the spec alone.
        transitive = l.transitivePackages(_spec)
    }
}

items = [_core] + ([_packageObject(p) for p in _packages] if _pkgOpen else []) + ([_providerConfigObject(i, pc) for i, pc in _profile.providerConfigs] if _pcOpen else []) + [_status]
