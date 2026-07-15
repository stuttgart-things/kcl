"""
xplane-ip-reservation — function-kcl module for the ip-reservation Configuration.

Reserves IP addresses from clusterbook, using the internalNetworkKey discovered
from a RemoteCluster (provider-kubeconfig):

  1. kubernetes.m Object (Observe) — reads RemoteCluster.status.internalNetworkKey
  2. kubernetes.m Object (wrapper) — an IPReservation (provider-clusterbook),
     emitted once the networkKey is known

Render and status run in a single pass: the module emits the Observe Object and
the IPReservation wrapper AND patches the XR status from `ocds`. On early
reconciles the networkKey is empty (Observe not yet populated), so the
IPReservation is withheld and status stays unready until it converges.

Cluster-scoped MRs (RemoteCluster, IPReservation) are wrapped in namespaced
kubernetes.m Objects because the XR is namespaced (scope: Namespaced). Both
Objects use the in-cluster (InjectedIdentity) provider config to read/write on
the management cluster.
"""

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}
_name = _meta?.name or "ip-reservation"

_clusterName = _spec?.clusterName
_count = _spec?.count or 1
_ip = _spec?.ip or ""
_createDNS = _spec?.createDNS or False
_cbPcr = _spec?.clusterbookProviderConfigRef or "default"
# The Object provider config for management-cluster reads/wraps. InjectedIdentity.
_k8sPcr = _spec?.kubernetesProviderConfigRef or "in-cluster"

_rcKey = "{}-observe-rc".format(_name)
_ipKey = "{}-ip".format(_name)

# --- Resource 1: Observe the RemoteCluster to read internalNetworkKey ---
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
            name = _k8sPcr
            kind = "ClusterProviderConfig"
        }
    }
}

# --- Read networkKey from the observed RemoteCluster status ---
_networkKey = _ocds[_rcKey].Resource?.status?.atProvider?.manifest?.status?.atProvider?.internalNetworkKey or "" if _rcKey in _ocds else ""

# --- Resource 2: IPReservation wrapped in an Object (once networkKey known) ---
_ipSpec = {
    networkKey = _networkKey
    clusterName = _clusterName
    count = _count
    createDNS = _createDNS
    **({ip = _ip} if _ip else {})
}
_ipObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {
        name = _ipKey
        namespace = _meta?.namespace
        annotations = {
            "krm.kcl.dev/composition-resource-name" = _ipKey
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "ipreservation.clusterbook.stuttgart-things.com/v1alpha1"
                kind = "IPReservation"
                metadata = {
                    name = _ipKey
                }
                spec = {
                    forProvider = _ipSpec
                    providerConfigRef = {
                        name = _cbPcr
                        kind = "ClusterProviderConfig"
                    }
                }
            }
        }
        providerConfigRef = {
            name = _k8sPcr
            kind = "ClusterProviderConfig"
        }
        readiness = {
            policy = "DeriveFromObject"
        }
    }
}
_ipResources = [_ipObj] if _networkKey != "" else []

# --- Status: read IPReservation status back off the wrapping Object via ocds ---
_isReady = lambda resourceName: str -> bool {
    _found = resourceName in _ocds
    _conds = _ocds[resourceName]?.Resource?.status?.conditions or [] if _found else []
    len([c for c in _conds if c.type == "Ready" and c.status == "True"]) > 0
}

_ipAt = _ocds[_ipKey].Resource?.status?.atProvider?.manifest?.status?.atProvider or {} if _ipKey in _ocds else {}
_ipAddresses = _ipAt?.ipAddresses or []
_resStatus = _ipAt?.status or ""
_fqdn = _ipAt?.fqdn or ""
_zone = _ipAt?.zone or ""

_xrStatus = _oxr | {
    status = {
        ready = _isReady(_ipKey)
        networkKey = _networkKey
        ipAddresses = _ipAddresses
        reservationStatus = _resStatus
        fqdn = _fqdn
        zone = _zone
    }
}

items = [_observeRC] + _ipResources + [_xrStatus]
