"""
xplane-capability — function-kcl module for the capability Crossplane Configuration.

A capability is what lets a cluster ACT on an external system. The provider runs
on every management cluster, but without a ClusterProviderConfig it does not know
where to connect, without credentials it may not log in, and without an
EnvironmentConfig it does not know which node, datastore or template to place a
VM on. This module emits those three objects onto a target cluster, one set per
enabled capability.

It replaces the per-capability Helm charts in stuttgart-things/stuttgart-things
for clusters that have external-secrets. Two things get better in the move, and
both are consequences of running inside Crossplane rather than beside it:

  * the Vault auth mount and the ClusterSecretStore no longer have to be passed
    in. The charts take `authMountPath` with the comment "appset injects
    <cluster>-eso per cluster"; here the cluster name IS the XR's, so the same
    derivation happens where the fact lives.
  * package installation stays out. The charts can install the Configuration and
    the Provider, which is what their long comments about duplicate lock nodes
    are about; that job belongs to the management-plane Configuration, which
    uses the CR names Crossplane itself derives.

What it does NOT do is the sops and sops-git credential backends. Those exist so
a cluster without Vault can still have credentials, and a cluster without Vault
cannot use this module at all — it would emit an ExternalSecret nothing serves.
For those clusters the charts remain the answer.
"""

import xplane_capability_catalog.main as cat
import xplane_capability_catalog.schema as capschema
import .logic

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}

_clusterName = _spec?.clusterName
_k8sPcr = _spec?.kubernetesProviderConfigRef

# Where the credential Secret and the ExternalSecret land ON THE TARGET. The
# provider reads its Secret from here, so it is not the XR's own namespace.
_ns = _spec?.namespace or "crossplane-system"
_environment = _spec?.environment or _clusterName

# The ClusterSecretStore to read from. Derived rather than required: the
# platform Configuration creates it as `vault-cluster-secrets` through the
# external-secrets app, and a cluster that has a store under another name says
# so once here instead of once per capability.
_storeName = _spec?.secretStoreName or "vault-cluster-secrets"

# Where the capability's WORKLOAD secrets go — the namespace the VM XRs live in
# on the target cluster, which is not where the provider reads its credentials.
# The namespaced EnvironmentVM CRD resolves passwordSecretRef in the managed
# resource's own namespace, so a cloud-init password next to the provider is a
# Secret nothing reads.
_workloadNs = _spec?.workloadNamespace or "default"

# --- Vault coordinates for the stores this module creates -------------------
# A ClusterSecretStore fixes ONE KV mount, and capabilities do not share one:
# proxmox credentials live under cicd-proxmox-labul, vsphere under its own. So a
# capability that names a mount gets its own store rather than borrowing the
# cluster's.
#
# Everything except the mount is a property of the CLUSTER and is stated once
# here — and `mountPath` is the reason this module exists in this form: the Helm
# charts take it as a deploy-time parameter with the comment "appset injects
# <cluster>-eso per cluster", while here the cluster name is on the XR.
_vault = _spec?.vault or {}
_vaultServer = _vault?.server
_vaultAuth = _vault?.auth or {}
_authMountPath = _vaultAuth?.mountPath or (_clusterName + "-eso" if _clusterName else None)
_authRole = _vaultAuth?.role or "eso"
_authSaName = _vaultAuth?.serviceAccountName or "external-secrets"
_authSaNamespace = _vaultAuth?.serviceAccountNamespace or "external-secrets"
_caProvider = _vault?.caProvider or {}
_caName = _caProvider?.name or "vault-pki-ca"
_caNamespace = _caProvider?.namespace or "cert-manager"
_caKey = _caProvider?.key or "ca.crt"
_refreshInterval = _spec?.refreshInterval or "1h"

_capsIn = _spec?.capabilities or {}
_enabled = sorted([n for n in _capsIn if (_capsIn[n]?.enabled or False)])

# --- naming -----------------------------------------------------------------
# Every emitted object carries the environment label, because two environments
# on one cluster (labda AND labul) must not collide on a shared
# ClusterProviderConfig or credentials Secret. The charts solved this the same
# way; the difference is that the label defaults to the cluster name here rather
# than having to be set.
_objName = lambda capName: str -> str {
    capName + "-" + _environment
}

# Praefixt die komponierten Object-Namen mit clusterName. Die Regel samt
# Begruendung liegt in logic.k, damit sie testbar ist.
_resNameFor = lambda suffix: str -> str {
    logic.resourceName(_clusterName, _environment, suffix)
}

# `<capability>-creds-<env>` — NOT the charts' `proxmox-creds-<env>`. The
# difference is deliberate: on a cluster that still has the chart installed,
# colliding on the Secret name would give two owners to one object, and the ESO
# refresh of whichever lost would keep overwriting the other. Nothing else
# refers to this name — only the ClusterProviderConfig two functions down, which
# this module also emits — so a migration means deleting the chart's Secret, not
# renaming anything.
_credsSecretName = lambda capName: str -> str {
    capName + "-creds-" + _environment
}

# Where the credentials Secret goes. Beside the provider by default; a
# capability whose consumer reads it elsewhere says so with
# credentialsNamespaceField, and the value comes from its own placement — for
# ansible that is the Tekton pipeline's namespace, and a Secret in
# crossplane-system would simply never be read.
_credsNamespace = lambda capName: str -> str {
    logic.credentialsNamespace(capName, _placement(capName), _ns)
}

# A capability names a KV mount -> it gets its own store. Names one that already
# exists -> that one is used and nothing is created.
_vaultOf = lambda capName: str -> {str:} {
    _capSpec(capName)?.vault or {}
}
_needsStore = lambda capName: str -> bool {
    _v = _vaultOf(capName)
    not _v?.secretStoreName and bool(_v?.mount)
}

# `<capability>-<environment>`, NOT the charts' `vault-<mount>`. Matching that
# name on a cluster where the chart is still installed would give one store two
# owners, and each side would keep rewriting the other's spec.
_storeNameFor = lambda capName: str -> str {
    _v = _vaultOf(capName)
    _v?.secretStoreName or (_objName(capName) if _needsStore(capName) else _storeName)
}

# --- per-capability rendering ----------------------------------------------
_capSpec = lambda capName: str -> {str:} {
    _capsIn[capName] or {}
}

# Placement: catalog defaults, overridden by the XR. Only keys the catalog knows
# are emitted — see _unknownFields, which turns the rest into a hard error
# rather than a value that vanishes.
_given = lambda capName: str -> {str:} {
    _capSpec(capName)?.placement or {}
}
_placement = lambda capName: str -> {str:} {
    logic.placement(capName, _given(capName))
}

# Fail the whole render rather than emit a half-configured capability. A missing
# node or templateVmId does not surface as a validation error later — it
# surfaces as a VM the provider tries to place nowhere, minutes later, in a
# message that names the provider and not this XR.
_valid = logic.validate(_spec, _enabled, {n: _given(n) for n in _enabled})
_validStores = logic.validateStores(_enabled, {n: _vaultOf(n) for n in _enabled}, _vaultServer, _authMountPath)

# --- object wrapper ---------------------------------------------------------
# One provider-kubernetes Object per manifest, exactly as flux-apps does it.
# managementPolicies stay at the default (full control): unlike a namespace,
# these objects have no pre-existing owner to adopt — and a ClusterProviderConfig
# left behind after its Secret is gone is worse than none, because a VM XR then
# references a config that cannot authenticate.
# NOT DeriveFromObject for everything. provider-kubernetes derives readiness
# from the managed object's own conditions, and neither an EnvironmentConfig nor
# a ClusterProviderConfig HAS any — so those Objects sit at Ready=False forever
# while the thing they created is present and correct. Measured here on
# u26-rke2-1, and the same effect is documented for ClusterProviderConfig in
# crossplane-configurations#294, where DeriveFromCelQuery with a constant was
# the shape that worked.
#
# ExternalSecret keeps DeriveFromObject: it reports Ready, and that condition is
# the only signal that Vault actually answered — a capability whose credentials
# 403 must NOT report ready.
# The mapping itself lives in logic.k so it can be tested — see readinessFor.
_readyOnCreate = {policy = "DeriveFromCelQuery", celQuery = "true"}
_readyFromObject = {policy = "DeriveFromObject"}

_object = lambda resName: str, manifest: {str:}, readiness: {str:str} = _readyFromObject -> {str:} {
    {
        apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
        kind = "Object"
        metadata = {
            name = resName
            namespace = _meta?.namespace or "default"
            annotations = {"krm.kcl.dev/composition-resource-name" = resName}
        }
        spec = {
            providerConfigRef = {
                name = _k8sPcr
                kind = "ClusterProviderConfig"
            }
            forProvider = {manifest = manifest}
            readiness = readiness
        }
    }
}

_externalSecret = lambda capName: str -> {str:} {
    _c = cat.get(capName)
    _v = _capSpec(capName)?.vault or {}
    _resName = _resNameFor(capName + "-credentials")
    _object(_resName, {
        apiVersion = "external-secrets.io/v1"
        kind = "ExternalSecret"
        metadata = {
            name = _credsSecretName(capName)
            namespace = _credsNamespace(capName)
        }
        spec = {
            refreshInterval = _refreshInterval
            secretStoreRef = {
                kind = "ClusterSecretStore"
                name = _storeNameFor(capName)
            }
            target = {
                name = _credsSecretName(capName)
                creationPolicy = "Owner"
                # Retain matches the ESO default. Spelling it out keeps a
                # GitOps differ from reporting a permanent diff against a field
                # it did not set.
                deletionPolicy = "Retain"
                template = {
                    engineVersion = "v2"
                    mergePolicy = "Replace"
                    data = _c.credentials.data
                }
            }
            dataFrom = [{
                extract = {
                    key = _v?.secret or "default"
                    conversionStrategy = "Default"
                    decodingStrategy = "None"
                    metadataPolicy = "None"
                }
            }]
        }
    })
}

# One ExternalSecret per declared workload secret. Shares the capability's Vault
# secret — a second `extract` of the same KV entry, not a second credential.
_workloadSecret = lambda capName: str, w: capschema.WorkloadSecret, idx: int -> {str:} {
    _v = _capSpec(capName)?.vault or {}
    _secretName = capName + "-" + w.nameSuffix
    _resName = _resNameFor(capName + "-" + w.nameSuffix + "-secret")
    _object(_resName, {
        apiVersion = "external-secrets.io/v1"
        kind = "ExternalSecret"
        metadata = {
            name = _secretName
            namespace = _workloadNs
        }
        spec = {
            refreshInterval = _refreshInterval
            secretStoreRef = {
                kind = "ClusterSecretStore"
                name = _storeNameFor(capName)
            }
            target = {
                name = _secretName
                creationPolicy = "Owner"
                deletionPolicy = "Retain"
                template = {
                    engineVersion = "v2"
                    mergePolicy = "Replace"
                    data = w.data
                }
            }
            dataFrom = [{
                extract = {
                    key = _v?.secret or "default"
                    conversionStrategy = "Default"
                    decodingStrategy = "None"
                    metadataPolicy = "None"
                }
            }]
        }
    })
}

_workloadSecretNames = lambda capName: str -> {str:str} {
    {"ciPasswordSecretName": capName + "-" + w.nameSuffix for w in cat.get(capName).workloadSecrets if w.nameSuffix == "ci-password"}
}

_secretStore = lambda capName: str -> {str:} {
    _v = _vaultOf(capName)
    _resName = _resNameFor(capName + "-secret-store")

    # Cluster-scoped: a ClusterSecretStore has no namespace, and an
    # ExternalSecret in any namespace may reference it — which is what the
    # workload secret in a different namespace depends on.
    _object(_resName, {
        apiVersion = "external-secrets.io/v1"
        kind = "ClusterSecretStore"
        metadata = {name = _storeNameFor(capName)}
        spec = {
            provider = {
                vault = {
                    server = _v?.server or _vaultServer
                    path = _v.mount
                    version = "v2"
                    caProvider = {
                        type = "Secret"
                        name = _caName
                        namespace = _caNamespace
                        key = _caKey
                    }
                    auth = {
                        kubernetes = {
                            mountPath = _authMountPath
                            role = _authRole
                            serviceAccountRef = {
                                name = _authSaName
                                namespace = _authSaNamespace
                            }
                        }
                    }
                }
            }
        }
    })
}

_providerConfig = lambda capName: str -> {str:} {
    _c = cat.get(capName)
    _pc = _c.providerConfig
    _resName = _resNameFor(capName + "-provider-config")
    _object(_resName, {
        apiVersion = _pc.apiVersion
        kind = _pc.kind
        metadata = {name = _objName(capName)}
        spec = {
            credentials = {
                source = "Secret"
                secretRef = {
                    name = _credsSecretName(capName)
                    namespace = _ns
                    key = _pc.credentialsKey
                }
            }
        }
    }, _readyOnCreate)
}

_environmentConfig = lambda capName: str -> {str:} {
    _c = cat.get(capName)
    _resName = _resNameFor(capName + "-environment-config")

    # providerConfigName/-Kind are DERIVED, never taken from the XR: they name
    # the object rendered two functions up, and letting an XR state them makes
    # it possible to point a VM at a config this XR did not create.
    # Derived, never taken from the XR: each names an object rendered by this
    # same module, and letting an XR state one makes it possible to point a
    # consumer at something this XR did not create — or at a name that does not
    # exist, which reads as a missing credential rather than a wrong name.
    _derived = ({
        providerConfigName = _objName(capName)
        providerConfigKind = _c.providerConfig.kind
    } if _c?.providerConfig else {}) | _workloadSecretNames(capName) | ({
        (_c.credentialsNameField) = _credsSecretName(capName)
    } if _c?.credentialsNameField else {})
    _object(_resName, {
        apiVersion = "apiextensions.crossplane.io/v1beta1"
        kind = "EnvironmentConfig"
        metadata = {
            name = _objName(capName)
            labels = {(_c.environmentLabelKey) = _environment}
        }
        data = _placement(capName) | _derived
    }, _readyOnCreate)
}

_capObjects = lambda capName: str -> [{str:}] {
    _c = cat.get(capName)
    ([_secretStore(capName)] if _needsStore(capName) else []) + [_externalSecret(capName), _environmentConfig(capName)] + ([_providerConfig(capName)] if _c?.providerConfig else []) + [_workloadSecret(capName, _c.workloadSecrets[i], i) for i in range(len(_c.workloadSecrets))]
}

_objects = sum([_capObjects(n) for n in _enabled], [])

# --- status -----------------------------------------------------------------
_isReady = lambda resName: str -> bool {
    _found = resName in _ocds
    _conds = _ocds[resName]?.Resource?.status?.conditions or [] if _found else []
    len([c for c in _conds if c.type == "Ready" and c.status == "True"]) > 0
}

_capReady = lambda capName: str -> bool {
    _names = [o.metadata.name for o in _capObjects(capName)]
    len([n for n in _names if _isReady(n)]) == len(_names)
}

_readyCaps = [n for n in _enabled if _capReady(n)]
_allReady = len(_readyCaps) == len(_enabled) if _enabled else True

_xrStatus = _oxr | {
    status = {
        ready = _allReady
        capabilityCount = len(_enabled)
        readyCount = len(_readyCaps)
        capabilities = {n: {
            ready = _capReady(n)
            environmentConfig = _objName(n)
            credentialsSecret = _credsSecretName(n)
            secretStore = _storeNameFor(n)
            **({providerConfig = _objName(n)} if cat.get(n)?.providerConfig else {})
        } for n in _enabled}
    }
}

items = _objects + [_xrStatus]
