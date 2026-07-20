"""
xplane-cni — function-kcl module for the cni Crossplane Configuration.

Installs a CNI on a target cluster:
  1. kubernetes.m.crossplane.io Object — RemoteCluster observe (gate, optional)
  2. helm.m.crossplane.io Release      — the CNI chart (cilium today)

Render and status happen in a single pass: the module emits the managed
resources AND patches the XR status from `ocds` (observed composed resources).
On the first reconcile `ocds` is empty, so status.ready starts False and
converges as the Release becomes Ready.

This is the component every other platform component waits on. A cluster with
no CNI has NotReady nodes, so nothing schedules — a Helm install aimed at it
does not fail fast, it times out and retries. Consumers should gate on
status.ready rather than racing it.

All decision logic lives in logic.k so it is unit-testable without Crossplane;
this file only marshals option("params") in and `items` out.
"""

import .logic as l

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}
_name = _meta?.name or "cni"

_valid = l.validate(_spec)

# --- Provider config refs: explicit spec wins, else derived from clusterName ---
# Same derivation as flux-init: {clusterName}-helm / {clusterName}-kubernetes are
# the names provider-kubeconfig's RemoteCluster creates for the target cluster.
_clusterName = _spec?.clusterName or ""
_helmPcr = _spec?.helmProviderConfigRef or ("{}-helm".format(_clusterName) if _clusterName else "")
_k8sPcr = _spec?.kubernetesProviderConfigRef or ("{}-kubernetes".format(_clusterName) if _clusterName else "")
_observePcr = _spec?.observeProviderConfigRef or "in-cluster"

_ns = _spec?.namespace or "kube-system"
_chart = l.chart(_spec)

# --- Resource 1: observe the RemoteCluster (only when clusterName is set) ---
# Holds the install until the RemoteCluster resolves, so the derived provider
# config exists before we install through it. Without clusterName there is
# nothing to observe and the gate is always open.
_rcKey = "{}-observe-rc".format(_name)
_observeResources = []
_clusterType = ""
if _clusterName:
    _observeRC = {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = _rcKey
            namespace = _meta?.namespace
            annotations = {
                "krm.kcl.dev/composition-resource-name" = _rcKey
            }
        }
        spec = {
            managementPolicies = ["Observe"]
            forProvider = {
                manifest = {
                    apiVersion = "kubeconfig.stuttgart-things.com/v1alpha1"
                    kind = "RemoteCluster"
                    metadata = {
                        name = _clusterName
                    }
                }
            }
            providerConfigRef = {
                name = _observePcr
                kind = "ClusterProviderConfig"
            }
        }
    }
    _observeResources = [_observeRC]
    _clusterType = _ocds[_rcKey].Resource?.status?.atProvider?.manifest?.status?.atProvider?.clusterType or "" if _rcKey in _ocds else ""

_observeReady = bool(_clusterType) if _clusterName else True

# --- Resource 2: the CNI Helm Release ---
# external-name is the provider name, not the XR name: the chart owns
# cluster-wide DaemonSets and CRDs, so two releases of it under different names
# would fight. Pinning the release name makes a rename of the XR an adoption
# rather than a second install.
_releaseName = "{}-{}".format(_name, l.provider(_spec))
_release = {
    apiVersion = "helm.m.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = _releaseName
        namespace = _ns
        annotations = {
            "krm.kcl.dev/composition-resource-name" = _releaseName
            "crossplane.io/external-name" = l.provider(_spec)
        }
    }
    spec = {
        providerConfigRef = {
            name = _helmPcr
            kind = "ClusterProviderConfig"
        }
        forProvider = {
            chart = _chart
            namespace = _ns
            values = l.values(_spec)
        }
        rollbackLimit = 3
    }
}

_cniResources = [_release] if _observeReady else []

# --- Status: read Ready condition off each composed resource via ocds ---
_isReady = lambda resourceName: str -> bool {
    _found = resourceName in _ocds
    _conds = _ocds[resourceName]?.Resource?.status?.conditions or [] if _found else []
    len([c for c in _conds if c.type == "Ready" and c.status == "True"]) > 0
}

_releaseReady = _isReady(_releaseName)

_xrStatus = _oxr | {
    status = {
        provider = l.provider(_spec)
        version = _chart.version
        releaseReady = _releaseReady
        ready = _releaseReady and _observeReady
        clusterType = _clusterType
    }
}

items = _observeResources + _cniResources + [_xrStatus]
