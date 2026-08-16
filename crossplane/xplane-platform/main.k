"""
xplane-platform — function-kcl module for the platform Crossplane Configuration.

Composes one child XR per enabled component of a cluster's platform:
  0. Cni       (cni Configuration)        — cluster networking; opt-in, and the
     other children are gated on it, because a cluster with no CNI has NotReady
     nodes and a Helm install aimed at it times out rather than failing fast
  1. FluxInit  (flux-init Configuration)  — Flux itself, plus one OCIRepository
     source per enabled app
  2. FluxApps  (flux-apps Configuration)  — one Kustomization per enabled
     component of each enabled app

Render and status happen in a single pass: the module emits the child XRs AND
patches the XR status from `ocds`. On the first reconcile `ocds` is empty, so
status.ready starts False and converges as the children become Ready.

All decision logic lives in logic.k so it is unit-testable without Crossplane;
this file only marshals option("params") in and `items` out.
"""

import .logic as l

_params = option("params") or {}
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}

_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}
_name = _meta?.name or "platform"
_namespace = _meta?.namespace or "default"

_shared = l.resolveShared(_spec)

_fluxEnabled = l.fluxInitEnabled(_spec)
_apps = l.enabledApps(_spec)
_appsEnabled = len(_apps) > 0
_cniEnabled = l.cniEnabled(_spec)
_ciliumEnabled = l.ciliumEnabled(_spec)
_ipResEnabled = l.ipReservationEnabled(_spec)
_vaultIssuerEnabled = l.vaultIssuerEnabled(_spec)

_cniKey = "{}-cni".format(_name)
_fluxKey = "{}-flux-init".format(_name)
_appsKey = "{}-flux-apps".format(_name)
_ciliumKey = "{}-cilium".format(_name)
_ipResKey = "{}-ip-reservation".format(_name)
_vaultAuthKey = "{}-vault-auth".format(_name)
_vaultPkiKey = "{}-vault-pki".format(_name)
_issuerKey = "{}-cluster-issuer".format(_name)
_tokenReqKey = "{}-cert-manager-tokenrequest".format(_name)

# --- Read child status back (needed by the CNI gate below, so defined early) ---
_readStatus = lambda key: str -> {str:} {
    (_ocds[key].Resource?.status or {}) if key in _ocds else {}
}
_isReady = lambda st: {str:} -> bool {
    len([c for c in (st?.conditions or []) if c.type == "Ready" and c.status == "True"]) > 0
}

# --- Facts this Platform discovered, keyed the way the catalog addresses them ---
# The keys ARE the component names, so a catalog `substitutionSources` path reads
# like the status it comes from: "ipReservation.domain" is
# status.components.ipReservation.domain. Same values the status block below
# publishes — built once here so the two cannot drift apart.
#
# Only facts belong here. A value a cluster CHOOSES (which Secret a certificate
# lands in) has no entry and stays the XR's job.
_discovered = {
    ipReservation = {
        domain = l.clusterDomain(_readStatus(_ipResKey)?.fqdn or "")
        ipAddresses = _readStatus(_ipResKey)?.ipAddresses or []
        zone = _readStatus(_ipResKey)?.zone or ""
    }
    vaultIssuer = {
        # Keyed by auth name, unlike the VaultK8sAuth's own status, which keeps
        # the list it was given. Different layers, different jobs: there the
        # status mirrors what was asked for, here it is ADDRESSED — a catalog
        # entry says `vaultIssuer.auths.eso.mountPath`, and an index would break
        # the moment someone reorders spec.vaultIssuer.additionalAuths.
        auths = {a.name: a for a in ((_readStatus(_vaultAuthKey)?.share or {})?.auths or []) if a?.name}
    }
}

# Validated against what was discovered: a variable the platform can supply is
# not "missing" just because the XR omitted it — that is the point of
# substitutionSources. One that resolves to nothing still fails, by name.
_valid = l.validate(_spec, _discovered)

# --- Child 0: Cni ---
# Not just another component: until it is Ready the target cluster's nodes are
# NotReady, so nothing schedules — and a Helm install aimed at such a cluster
# does not fail fast, it times out and retries. So the other children are held
# until this one reports ready.
_cniSpec = _spec?.cni or {}
_cniStatus = _readStatus(_cniKey)
_cniReady = _isReady(_cniStatus)

_cniXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "Cni"
    metadata = {
        name = _cniKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _cniKey}
    }
    spec = {
        if _shared?.clusterName:
            clusterName = _shared.clusterName
        if _shared.helmProviderConfigRef:
            helmProviderConfigRef = _shared.helmProviderConfigRef
        observeProviderConfigRef = _shared.observeProviderConfigRef
        if _cniSpec?.provider:
            provider = _cniSpec.provider
        # NOT _shared.namespace: that is the Flux namespace. A CNI belongs in
        # kube-system, which the cni Configuration defaults to on its own.
        if _cniSpec?.namespace:
            namespace = _cniSpec.namespace
        if _cniSpec?.chart:
            chart = _cniSpec.chart
        if _cniSpec?.cilium:
            cilium = _cniSpec.cilium
        if _cniSpec?.values:
            values = _cniSpec.values
    }
}

# One-way gate: once a child exists, keep emitting it even if the CNI blips
# not-Ready during a chart upgrade — otherwise Crossplane would delete it.
_networkReady = _cniReady if _cniEnabled else True

# --- Child 1: FluxInit ---
# Sources are the union of what the XR declared and what enabling an app
# implies. The app-derived ones are what make `apps: {dapr: {}}` sufficient.
_fluxSpec = _spec?.fluxInit or {}
_declaredSources = ((_fluxSpec?.instance or {})?.sources or [])
_allSources = _declaredSources + l.appSources(_spec)

_fluxInitXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "FluxInit"
    metadata = {
        name = _fluxKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _fluxKey}
    }
    spec = {
        if _shared?.clusterName:
            clusterName = _shared.clusterName
        if _shared.helmProviderConfigRef:
            helmProviderConfigRef = _shared.helmProviderConfigRef
        if _shared.kubernetesProviderConfigRef:
            kubernetesProviderConfigRef = _shared.kubernetesProviderConfigRef
        observeProviderConfigRef = _shared.observeProviderConfigRef
        namespace = _shared.namespace
        if _fluxSpec?.operatorChart:
            operatorChart = _fluxSpec.operatorChart
        if (_fluxSpec?.instance or _allSources):
            instance = (_fluxSpec?.instance or {}) | ({sources = _allSources} if _allSources else {})
        if _fluxSpec?.kustomize:
            kustomize = _fluxSpec.kustomize
        if _fluxSpec?.sops:
            sops = _fluxSpec.sops
    }
}

# --- Child 2: FluxApps ---
# Only the kubernetes ref is projected: flux-apps takes no clusterName and no
# helm ref, so the shared contract is applied per component, not forwarded whole.
_fluxAppsXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "FluxApps"
    metadata = {
        name = _appsKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _appsKey}
    }
    spec = {
        kubernetesProviderConfigRef = _shared.kubernetesProviderConfigRef
        namespace = _shared.namespace
        apps = l.appEntries(_spec, _discovered)
    }
}

# --- Child 3: XIPReservation ---
# Reserves a clusterbook IP on the MANAGEMENT cluster (independent of the target
# CNI, so not network-gated). When cilium's dynamic LB is also enabled its
# reservationRef auto-wires to this child.
_ipResSpec = _spec?.ipReservation or {}
_ipReservationXR = {
    apiVersion = "resources.stuttgart-things.com/v1alpha1"
    kind = "XIPReservation"
    metadata = {
        name = _ipResKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _ipResKey}
    }
    spec = {
        if _shared?.clusterName:
            clusterName = _shared.clusterName
        if _ipResSpec?.count:
            count = _ipResSpec.count
        if _ipResSpec?.ip:
            ip = _ipResSpec.ip
        if "createDNS" in _ipResSpec:
            createDNS = _ipResSpec.createDNS
        if _ipResSpec?.clusterbookProviderConfigRef:
            clusterbookProviderConfigRef = _ipResSpec.clusterbookProviderConfigRef
        # the XIPReservation observes the RemoteCluster in-cluster on the mgmt cluster
        kubernetesProviderConfigRef = _shared.observeProviderConfigRef
    }
}

# --- Child 4: Cilium (LoadBalancer + Gateway) ---
# Superset services on top of the CNI: LB pool + L2 announcement + Gateway.
# Defaults install.enabled=false (the CNI is `cni`'s job / already present) — it
# only layers the services, so it is gated on the network being up. When dynamic
# LB is requested and no reservationRef is set, auto-wire it to the ipReservation
# child so the reserved IP becomes the pool block.
_ciliumSpec = _spec?.cilium or {}
_ciliumInstall = _ciliumSpec?.install or {enabled = False}
_ciliumLB = _ciliumSpec?.loadBalancer or {}
_wantAutoRef = _ipResEnabled and (_ciliumLB?.ipMode or "static") == "dynamic" and not _ciliumLB?.reservationRef
_ciliumLBOut = _ciliumLB | ({reservationRef = _ipResKey} if _wantAutoRef else {})
_ciliumXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "Cilium"
    metadata = {
        name = _ciliumKey
        namespace = _namespace
        annotations = {"krm.kcl.dev/composition-resource-name" = _ciliumKey}
    }
    spec = {
        if _shared?.clusterName:
            clusterName = _shared.clusterName
        if _shared.helmProviderConfigRef:
            helmProviderConfigRef = _shared.helmProviderConfigRef
        if _shared.kubernetesProviderConfigRef:
            kubernetesProviderConfigRef = _shared.kubernetesProviderConfigRef
        install = _ciliumInstall
        if _ciliumLBOut:
            loadBalancer = _ciliumLBOut
        if _ciliumSpec?.gateway:
            gateway = _ciliumSpec.gateway
    }
}

# --- Vault-issuer children (tokenless cert-manager -> Vault-PKI) ---
# 5 resources: VaultK8sAuth (Vault mount, opentofu Workspace via AppRole),
# VaultPkiSecret (CA bundle -> target cert-manager ns), and three
# provider-kubernetes Objects on the target (k8s-auth ClusterIssuer +
# TokenRequest Role/RoleBinding). cert-manager's CONTROLLER comes via
# apps.cert-manager (FluxApps); this only wires the tokenless issuer.
# Prereqs on the mgmt cluster in _namespace: the AppRole tfvars secret, the
# reviewer backendConfig secret, and the source CA secret.
_viSpec = _spec?.vaultIssuer or {}
_viAuthName = _viSpec?.authName or "certmanager"
_viCmNs = _viSpec?.certManagerNamespace or "cert-manager"
_viPkiMount = _viSpec?.pkiMount or "pki"
_viIssuerName = _viSpec?.issuerName or "vault-pki-k8s"
_viCaSecret = _viSpec?.caSecretName or "vault-pki-ca"
_viTargetRef = _shared.kubernetesProviderConfigRef

# --- Reviewer JWT provisioning (auto) ---
# Vault's k8s-auth mount needs a token_reviewer_jwt from the TARGET (an
# auth-delegator SA), which the VaultK8sAuth Workspace reads from a secret on
# the MGMT cluster. autoReviewer provisions the whole chain: an auth-delegator
# SA + long-lived token Secret on the target, an Observe of that Secret, and a
# copy of its ca.crt+token into a mgmt Secret. An explicit reviewerSecret skips
# it. Verified: provider-kubernetes Observe exposes a Secret's data, so the copy
# needs no external step.
_viReviewerObserveKey = "{}-reviewer-observe".format(_name)
_viReviewerMgmtSecret = "{}-reviewer".format(_name)
_viAutoReviewer = _viSpec.autoReviewer if "autoReviewer" in _viSpec else (not _viSpec?.reviewerSecret)

# Observed reviewer ca.crt + token from the target Secret (empty until observed).
_viRevData = (_ocds[_viReviewerObserveKey].Resource?.status?.atProvider?.manifest?.data or {}) if _viReviewerObserveKey in _ocds else {}
_viRevToken = _viRevData?.token or ""
_viRevCa = _viRevData["ca.crt"] if "ca.crt" in _viRevData else ""

# The reviewer secret the Workspace reads, and whether it is available yet.
_viEffReviewerSecret = _viReviewerMgmtSecret if _viAutoReviewer else (_viSpec?.reviewerSecret or "")
_viReviewerAvailable = (_viRevToken != "") if _viAutoReviewer else (_viSpec?.reviewerSecret != None)

_vaultK8sAuthXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "VaultK8sAuth"
    metadata = {name = _vaultAuthKey, namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = _vaultAuthKey}}
    spec = {
        if _shared?.clusterName:
            clusterName = _shared.clusterName
        vaultAddr = _viSpec?.vaultAddr or ""
        skipTlsVerify = _viSpec.skipTlsVerify if "skipTlsVerify" in _viSpec else True
        if _viSpec?.kubernetesHost:
            kubernetesHost = _viSpec.kubernetesHost
        vaultTokenSecret = _viSpec?.approleSecret or "vault-approle"
        providerConfigName = _viSpec?.opentofuProviderConfigRef or "in-cluster"
        providerConfigKind = "ClusterProviderConfig"
        k8sAuths = [{
            name = _viAuthName
            tokenPolicies = _viSpec?.tokenPolicies or ["pki-issue"]
            boundServiceAccountNames = ["cert-manager"]
            boundServiceAccountNamespaces = [_viCmNs]
            # Config the mount only once a reviewer secret exists (auto or
            # explicit); until then the Workspace just creates the mount+role and
            # adds the backend_config on a later reconcile.
            if _viReviewerAvailable:
                backendConfig = {secretName = _viEffReviewerSecret, secretNamespace = _namespace}
        }] + [{
            # Further auths on the SAME Vault mount machinery — external-secrets
            # is the reason this exists: it needs its own mount and role, bound
            # to its own ServiceAccount, with its own policies. Reusing
            # cert-manager's would hand a secrets reader the right to issue
            # certificates.
            name = a?.name or "extra"
            boundServiceAccountNames = a?.boundServiceAccountNames or ["default"]
            boundServiceAccountNamespaces = a?.boundServiceAccountNamespaces or ["default"]
            if a?.tokenPolicies:
                tokenPolicies = a.tokenPolicies
            if a?.policies:
                policies = a.policies
            if _viReviewerAvailable:
                backendConfig = {secretName = _viEffReviewerSecret, secretNamespace = _namespace}
        } for a in (_viSpec?.additionalAuths or [])]
    }
}

_vaultPkiSecretXR = {
    apiVersion = "config.stuttgart-things.com/v1alpha1"
    kind = "VaultPkiSecret"
    metadata = {name = _vaultPkiKey, namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = _vaultPkiKey}}
    spec = {
        providerConfigRef = _viTargetRef
        providerConfigKind = "ClusterProviderConfig"
        namespace = _viCmNs
        caSecretName = _viCaSecret
        caBundleSecretRef = {name = _viSpec?.caSourceSecret or "vault-pki-source-ca", namespace = _namespace}
    }
}

_issuerObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = _issuerKey, namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = _issuerKey}}
    spec = {
        forProvider.manifest = {
            apiVersion = "cert-manager.io/v1"
            kind = "ClusterIssuer"
            metadata.name = _viIssuerName
            spec.vault = {
                server = _viSpec?.vaultAddr or ""
                path = "{}/sign/{}".format(_viPkiMount, _viSpec?.pkiRole or "")
                caBundleSecretRef = {name = _viCaSecret, key = "ca.crt"}
                auth.kubernetes = {
                    mountPath = "/v1/auth/{}-{}".format(_shared?.clusterName or "", _viAuthName)
                    role = _viAuthName
                    serviceAccountRef.name = "cert-manager"
                }
            }
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}

_tokenReqRoleObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = "{}-role".format(_tokenReqKey), namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = "{}-role".format(_tokenReqKey)}}
    spec = {
        forProvider.manifest = {
            apiVersion = "rbac.authorization.k8s.io/v1"
            kind = "Role"
            metadata = {name = "cert-manager-tokenrequest", namespace = _viCmNs}
            rules = [{apiGroups = [""], resources = ["serviceaccounts/token"], resourceNames = ["cert-manager"], verbs = ["create"]}]
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}

_tokenReqBindingObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = "{}-binding".format(_tokenReqKey), namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = "{}-binding".format(_tokenReqKey)}}
    spec = {
        forProvider.manifest = {
            apiVersion = "rbac.authorization.k8s.io/v1"
            kind = "RoleBinding"
            metadata = {name = "cert-manager-tokenrequest", namespace = _viCmNs}
            roleRef = {apiGroup = "rbac.authorization.k8s.io", kind = "Role", name = "cert-manager-tokenrequest"}
            subjects = [{kind = "ServiceAccount", name = "cert-manager", namespace = _viCmNs}]
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}

# --- auto-reviewer Objects (only when autoReviewer) ---
_viRevSAObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = "{}-reviewer-sa".format(_name), namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = "{}-reviewer-sa".format(_name)}}
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "ServiceAccount"
            metadata = {name = "vault-auth-reviewer", namespace = "kube-system"}
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}
_viRevCRBObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = "{}-reviewer-crb".format(_name), namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = "{}-reviewer-crb".format(_name)}}
    spec = {
        forProvider.manifest = {
            apiVersion = "rbac.authorization.k8s.io/v1"
            kind = "ClusterRoleBinding"
            metadata.name = "vault-auth-reviewer"
            roleRef = {apiGroup = "rbac.authorization.k8s.io", kind = "ClusterRole", name = "system:auth-delegator"}
            subjects = [{kind = "ServiceAccount", name = "vault-auth-reviewer", namespace = "kube-system"}]
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}
_viRevTokenObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = "{}-reviewer-token".format(_name), namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = "{}-reviewer-token".format(_name)}}
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {name = "vault-auth-reviewer-token", namespace = "kube-system", annotations = {"kubernetes.io/service-account.name" = "vault-auth-reviewer"}}
            type = "kubernetes.io/service-account-token"
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}
_viRevObserveObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = _viReviewerObserveKey, namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = _viReviewerObserveKey}}
    spec = {
        managementPolicies = ["Observe"]
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {name = "vault-auth-reviewer-token", namespace = "kube-system"}
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}

# Copy the observed ca.crt + token into a mgmt Secret the Workspace reads. Only
# emitted once the token is observed (base64 values pass straight through).
_viRevMgmtObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = "{}-reviewer-secret".format(_name), namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = "{}-reviewer-secret".format(_name)}}
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {name = _viReviewerMgmtSecret, namespace = _namespace}
            type = "Opaque"
            data = {"ca.crt" = _viRevCa, token = _viRevToken}
        }
        providerConfigRef = {name = "in-cluster", kind = "ClusterProviderConfig"}
    }
}
_viReviewerObjects = ([_viRevSAObj, _viRevCRBObj, _viRevTokenObj, _viRevObserveObj] if _viAutoReviewer else []) + ([_viRevMgmtObj] if (_viAutoReviewer and _viRevToken != "") else [])

# --- Wildcard certificate for the cluster domain (opt-in) ---
# The last hand-made object of the Gateway path: cert-manager issues
# `*.{domain}` through the ClusterIssuer above into the Secret a Gateway
# listener names in certificateRefs. Nothing else composed it, so it survived
# no teardown and was reconciled by nothing.
#
# The domain comes from the ipReservation child, not the XR — the same value
# the cilium substitutions read, so the certificate and the listener hostname
# cannot disagree. Gated on it being discovered: a Certificate whose only
# dnsName is "*." is rejected, and one that never issues is worse than one that
# was never composed.
_viCertSpec = (_viSpec?.wildcardCertificate or {})
_viCertDomain = _discovered.ipReservation.domain
_viCertEnabled = l.wildcardCertEnabled(_spec, _viCertDomain)
_viCertSecret = _viCertSpec?.secretName or "wildcard-tls"
_viCertNs = _viCertSpec?.namespace or "default"
_viCertKey = "{}-wildcard-cert".format(_name)

_viCertObj = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {name = _viCertKey, namespace = _namespace, annotations = {"krm.kcl.dev/composition-resource-name" = _viCertKey}}
    spec = {
        forProvider.manifest = {
            apiVersion = "cert-manager.io/v1"
            kind = "Certificate"
            metadata = {name = _viCertSecret, namespace = _viCertNs}
            spec = {
                secretName = _viCertSecret
                commonName = "*.{}".format(_viCertDomain)
                dnsNames = ["*.{}".format(_viCertDomain)]
                # 90 days, renewed at 15 — well inside the PKI role's one-year
                # max_ttl, and short enough that a broken renewal surfaces while
                # the current certificate is still valid.
                duration = "2160h"
                renewBefore = "360h"
                issuerRef = {name = _viIssuerName, kind = "ClusterIssuer", group = "cert-manager.io"}
            }
        }
        providerConfigRef = {name = _viTargetRef, kind = "ClusterProviderConfig"}
    }
}

_vaultIssuerChildren = ([_vaultK8sAuthXR, _vaultPkiSecretXR, _issuerObj, _tokenReqRoleObj, _tokenReqBindingObj] + _viReviewerObjects + ([_viCertObj] if _viCertEnabled else [])) if _vaultIssuerEnabled else []

_children = ([_cniXR] if _cniEnabled else []) + ([_ipReservationXR] if _ipResEnabled else []) + ([_fluxInitXR] if (_fluxEnabled and l.gateOpen(_networkReady, _fluxKey in _ocds)) else []) + ([_fluxAppsXR] if (_appsEnabled and l.gateOpen(_networkReady, _appsKey in _ocds)) else []) + ([_ciliumXR] if (_ciliumEnabled and l.gateOpen(_networkReady, _ciliumKey in _ocds)) else []) + _vaultIssuerChildren

_fluxStatus = _readStatus(_fluxKey)
_fluxReady = _isReady(_fluxStatus)
_appsStatus = _readStatus(_appsKey)
_appsReady = _isReady(_appsStatus)
_ciliumStatus = _readStatus(_ciliumKey)
_ciliumReady = _isReady(_ciliumStatus)
_ipResStatus = _readStatus(_ipResKey)
_ipResReady = _isReady(_ipResStatus)
_vaultAuthReady = _isReady(_readStatus(_vaultAuthKey))
_vaultPkiReady = _isReady(_readStatus(_vaultPkiKey))
_issuerReady = _isReady(_readStatus(_issuerKey))
_vaultIssuerReady = _vaultAuthReady and _vaultPkiReady and _issuerReady

# clusterType is discovered by the FluxInit child from the RemoteCluster; lifting
# it into shared status keeps later components from re-observing it.
_clusterType = _fluxStatus?.clusterType or ""

_enabledReady = ([_cniReady] if _cniEnabled else []) + ([_ipResReady] if _ipResEnabled else []) + ([_fluxReady] if _fluxEnabled else []) + ([_appsReady] if _appsEnabled else []) + ([_ciliumReady] if _ciliumEnabled else []) + ([_vaultIssuerReady] if _vaultIssuerEnabled else [])
_readyComponents = len([r for r in _enabledReady if r])

_xrStatus = _oxr | {
    status = {
        shared = _shared | ({clusterType = _clusterType} if _clusterType else {})
        components = {
            cni = {
                enabled = _cniEnabled
                ready = _cniReady
                provider = _cniStatus?.provider or ""
                version = _cniStatus?.version or ""
            }
            fluxInit = {
                enabled = _fluxEnabled
                ready = _fluxReady
                operatorReady = _fluxStatus?.operatorReady or False
                instanceReady = _fluxStatus?.instanceReady or False
                sourcesReady = _fluxStatus?.sourcesReady or False
                sourceCount = _fluxStatus?.sourceCount or 0
            }
            fluxApps = {
                enabled = _appsEnabled
                ready = _appsReady
                appCount = _appsStatus?.appCount or 0
                readyCount = _appsStatus?.readyCount or 0
            }
            ipReservation = {
                enabled = _ipResEnabled
                ready = _ipResReady
                ipAddresses = _ipResStatus?.ipAddresses or []
                networkKey = _ipResStatus?.networkKey or ""
                # fqdn/zone verbatim from the child; domain is the wildcard
                # reduced to the usable name (see l.clusterDomain). Kept side by
                # side so a wrong domain can be traced to what clusterbook
                # actually returned rather than guessed at.
                fqdn = _ipResStatus?.fqdn or ""
                zone = _discovered.ipReservation.zone
                domain = _discovered.ipReservation.domain
            }
            cilium = {
                enabled = _ciliumEnabled
                ready = _ciliumReady
                loadBalancerReady = _ciliumStatus?.loadBalancerReady or False
                gatewayReady = _ciliumStatus?.gatewayReady or False
                networkKey = _ciliumStatus?.networkKey or ""
            }
            vaultIssuer = {
                enabled = _vaultIssuerEnabled
                ready = _vaultIssuerReady
                authReady = _vaultAuthReady
                caReady = _vaultPkiReady
                issuerReady = _issuerReady
                # What Vault actually created, keyed by auth name. This is what
                # lets external-secrets discover its own cluster's mount instead
                # of being told the name by hand — the gap that kept it out of
                # the catalog with substitutionSources.
                auths = _discovered.vaultIssuer.auths
            }
        }
        componentCount = len(_enabledReady)
        readyComponents = _readyComponents
        # Vacuously true with nothing enabled — matches what function-auto-ready
        # reports on the Ready condition when there is nothing to wait for.
        ready = _readyComponents == len(_enabledReady)
    }
}

items = _children + [_xrStatus]
