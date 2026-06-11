"""
Example usage of the RancherCluster XR from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.

The RancherCluster is intentionally thin: placement, distro, version, namespaces
and the Harvester infra fields come from the EnvironmentConfig selected by
`environmentConfig`. The claim only picks a `name`, an `infrastructure` and
(optionally) sizing, distro and an Argo CD registration toggle. Precedence is
explicit XR value > EnvironmentConfig > KCL default.

Templates
---------
minimal   : Just the XRD-required `name` (+ environmentConfig). distro, version,
            providerConfigRef etc. come from the EnvironmentConfig.
harvester : Harvester preset (infrastructure=harvester). Exposes per-node sizing
            (cpu/memory/disk/quantity) and the Argo CD toggle; infra identity
            (image/network/credential) comes from the EnvironmentConfig.
harvester-bootstrap : Like harvester, but Argo CD registration is ON by default and
            the cluster ships bootstrap-ready: IP/DNS reservation + the full
            platform-profile label set + vault-pki annotations baked in.
detailed  : Generic (custom-node) cluster with explicit distro, kubernetesVersion,
            namespaces, bootstrap namespace and full Argo CD registration.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_rancher_cluster as rc

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.rancherCluster?.spec or {}

# Coerce a -D string / params value into a bool. Returns `fallback` when unset.
_asBool = lambda v, fallback: bool -> bool {
    fallback if (v == None or v == "") else (str(v).lower() in ["true", "1", "yes"])
}

# Coerce a -D string / params value into an int. Returns `fallback` when unset.
_asInt = lambda v, fallback: int -> int {
    fallback if (v == None or v == "") else int(v)
}

# Template selector
_templateName = option("templateName") or _params?.templateName or "minimal"  # Options: "minimal", "harvester", "detailed"

# Identity
_name = _spec?.name or option("name") or _params?.name or "rancher-cluster"
_claimNamespace = _spec?.claimNamespace or option("claimNamespace") or _params?.claimNamespace or "default"
_environmentConfig = _spec?.environmentConfig or option("environmentConfig") or _params?.environmentConfig or "default"

# Optional placement / topology (default "" -> only emitted when set, so the
# EnvironmentConfig stays authoritative).
_providerConfigRef = _spec?.providerConfigRef or option("providerConfigRef") or _params?.providerConfigRef or ""
_rancherProviderConfigRef = _spec?.rancherProviderConfigRef or option("rancherProviderConfigRef") or _params?.rancherProviderConfigRef or ""
_distro = _spec?.distro or option("distro") or _params?.distro or ""
_kubernetesVersion = _spec?.kubernetesVersion or option("kubernetesVersion") or _params?.kubernetesVersion or ""
_rancherNamespace = _spec?.rancherNamespace or option("rancherNamespace") or _params?.rancherNamespace or ""
_bootstrapNamespace = _spec?.bootstrap?.namespace or option("bootstrapNamespace") or _params?.bootstrapNamespace or ""

# Harvester per-node sizing
_cpuCount = _asInt(_spec?.harvester?.cpuCount or option("cpuCount") or _params?.cpuCount, 2)
_memorySize = _asInt(_spec?.harvester?.memorySize or option("memorySize") or _params?.memorySize, 4)
_diskSize = _asInt(_spec?.harvester?.diskSize or option("diskSize") or _params?.diskSize, 40)
_quantity = _asInt(_spec?.harvester?.quantity or option("quantity") or _params?.quantity, 1)
_sshUser = _spec?.harvester?.sshUser or option("sshUser") or _params?.sshUser or ""

# Argo CD registration. Resolve register without `or` so an explicit `false` is
# not swallowed by the chain.
_registerOpt = option("argocdRegister")
_registerRaw = _registerOpt if _registerOpt != Undefined else (_params?.argocdRegister if _params?.argocdRegister != Undefined else _spec?.argocd?.register)
_argocdRegister = _asBool(_registerRaw, False)
_argocdNamespace = _spec?.argocd?.namespace or option("argocdNamespace") or _params?.argocdNamespace or ""
_argocdProviderConfigRef = _spec?.argocd?.providerConfigRef or option("argocdProviderConfigRef") or _params?.argocdProviderConfigRef or ""
_argocdServer = _spec?.argocd?.server or option("argocdServer") or _params?.argocdServer or ""

# Bootstrap template - Argo CD registration defaults ON, with IP/DNS reservation
# and the platform-profile label set + vault-pki annotations baked in.
_registerBootstrap = _asBool(_registerRaw, True)

# IP/DNS reservation. Resolve enabled without `or` so an explicit `false` is kept.
_reservationEnabledOpt = option("reservationEnabled")
_reservationEnabledRaw = _reservationEnabledOpt if _reservationEnabledOpt != Undefined else (_params?.reservationEnabled if _params?.reservationEnabled != Undefined else _spec?.argocd?.reservation?.enabled)
_reservationEnabled = _asBool(_reservationEnabledRaw, True)
_reservationNetworkKey = _spec?.argocd?.reservation?.networkKey or option("reservationNetworkKey") or _params?.reservationNetworkKey or ""
_reservationProviderConfigRef = _spec?.argocd?.reservation?.providerConfigRef or option("reservationProviderConfigRef") or _params?.reservationProviderConfigRef or ""

# vault-pki ClusterIssuer parameters (stamped as annotations on the cluster Secret).
_vaultServer = _spec?.argocd?.annotations?["clusterbook.stuttgart-things.com/vault-server"] or option("vaultServer") or _params?.vaultServer or "https://vault.infra.sthings.lab"
_vaultPkiPath = _spec?.argocd?.annotations?["clusterbook.stuttgart-things.com/vault-pki-path"] or option("vaultPkiPath") or _params?.vaultPkiPath or "pki/sign/sthings-lab"
_vaultTokenSecret = _spec?.argocd?.annotations?["clusterbook.stuttgart-things.com/vault-token-secret"] or option("vaultTokenSecret") or _params?.vaultTokenSecret or "cert-manager-vault-token"  # pragma: allowlist secret
_wildcardIssuerName = _spec?.argocd?.annotations?["clusterbook.stuttgart-things.com/wildcard-issuer-name"] or option("wildcardIssuerName") or _params?.wildcardIssuerName or "vault-pki"

# Minimal Template - only the XRD-required `name` plus the EnvironmentConfig
# selector. Everything else resolves from the EnvironmentConfig.
if _templateName == "minimal":
    rc.RancherCluster {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpec {
            name = _name
            environmentConfig = _environmentConfig
        }
    }

# Harvester Template - infrastructure fixed to harvester. Exposes per-node sizing
# and the Argo CD toggle; infra identity (image/network/credential/vmNamespace)
# comes from the EnvironmentConfig. Mirrors the proven k3s-xp XR.
if _templateName == "harvester":
    rc.RancherCluster {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpec {
            name = _name
            environmentConfig = _environmentConfig
            infrastructure = "harvester"
            if _distro:
                distro = _distro
            if _kubernetesVersion:
                kubernetesVersion = _kubernetesVersion
            harvester = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpecHarvester {
                cpuCount = _cpuCount
                memorySize = _memorySize
                diskSize = _diskSize
                quantity = _quantity
                if _sshUser:
                    sshUser = _sshUser
            }
            argocd = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocd {
                register = _argocdRegister
                if _argocdNamespace:
                    namespace = _argocdNamespace
                if _argocdProviderConfigRef:
                    providerConfigRef = _argocdProviderConfigRef
            }
        }
    }

# Harvester Bootstrap Template - same Harvester preset as `harvester`, but Argo CD
# registration is ON by default and the cluster ships with the full platform-profile
# label set + IP/DNS reservation + vault-pki annotations baked in. Mirrors the
# crossplane-mgmt showcase XR (k3s-xp): cluster-bootstrap-ready straight away.
if _templateName == "harvester-bootstrap":
    rc.RancherCluster {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpec {
            name = _name
            environmentConfig = _environmentConfig
            infrastructure = "harvester"
            if _distro:
                distro = _distro
            if _kubernetesVersion:
                kubernetesVersion = _kubernetesVersion
            harvester = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpecHarvester {
                cpuCount = _cpuCount
                memorySize = _memorySize
                diskSize = _diskSize
                quantity = _quantity
                if _sshUser:
                    sshUser = _sshUser
            }
            argocd = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocd {
                register = _registerBootstrap
                if _argocdNamespace:
                    namespace = _argocdNamespace
                if _argocdProviderConfigRef:
                    providerConfigRef = _argocdProviderConfigRef
                if _argocdServer:
                    server = _argocdServer
                # IP/DNS reservation via clusterbook-operator. REQUIRED for
                # network-platform: every network-platform AppSet selector needs the
                # allocation-ip anchor, only stamped when an IP is reserved.
                reservation = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocdReservation {
                    enabled = _reservationEnabled
                    createDNS = _reservationEnabled
                    if _reservationNetworkKey:
                        networkKey = _reservationNetworkKey
                    if _reservationProviderConfigRef:
                        providerConfigRef = _reservationProviderConfigRef
                }
                # Platform profile toggles -> copied onto the ClusterbookCluster /
                # Argo CD cluster Secret; the platforms/<profile> AppSets select on
                # them. storage-platform (openebs) + security-platform
                # (external-secrets + kyverno) + network-platform (cert-manager chain
                # + trust-manager + vault-pki ClusterIssuer). Cilium components stay
                # OFF (k3s default flannel, not Cilium CNI).
                labels = {
                    "storage-platform" = "true"
                    "storage-platform/openebs" = "true"
                    "security-platform" = "true"
                    "security-platform/external-secrets" = "true"
                    "security-platform/kyverno" = "true"
                    "network-platform" = "true"
                    "network-platform/cert-manager-install" = "true"
                    "network-platform/cert-manager-selfsigned" = "true"
                    "network-platform/cert-manager-cluster-ca" = "true"
                    "network-platform/cert-manager-vault-pki" = "true"
                    "network-platform/trust-manager-install" = "true"
                    "network-platform/trust-manager-bundle" = "true"
                }
                # Component parameters. The vault-pki ClusterIssuer reads these; the
                # token Secret is provisioned into cert-manager by the
                # vault-pki-secrets Configuration.
                annotations = {
                    "clusterbook.stuttgart-things.com/vault-server" = _vaultServer
                    "clusterbook.stuttgart-things.com/vault-pki-path" = _vaultPkiPath
                    "clusterbook.stuttgart-things.com/vault-token-secret" = _vaultTokenSecret
                    "clusterbook.stuttgart-things.com/wildcard-issuer-name" = _wildcardIssuerName
                }
            }
        }
    }

# Detailed Template - generic (custom-node) cluster with explicit distro,
# version, namespaces and full Argo CD registration. Mirrors the rke2-prod XR.
if _templateName == "detailed":
    rc.RancherCluster {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpec {
            name = _name
            environmentConfig = _environmentConfig
            infrastructure = _spec?.infrastructure or option("infrastructure") or _params?.infrastructure or "generic"
            if _providerConfigRef:
                providerConfigRef = _providerConfigRef
            if _rancherProviderConfigRef:
                rancherProviderConfigRef = _rancherProviderConfigRef
            if _distro:
                distro = _distro
            if _kubernetesVersion:
                kubernetesVersion = _kubernetesVersion
            if _rancherNamespace:
                rancherNamespace = _rancherNamespace
            if _spec?.clusterLabels:
                clusterLabels = _spec?.clusterLabels
            if _spec?.machineGlobalConfig:
                machineGlobalConfig = _spec?.machineGlobalConfig
            if _bootstrapNamespace:
                bootstrap = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpecBootstrap {
                    namespace = _bootstrapNamespace
                }
            argocd = rc.ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocd {
                register = _argocdRegister
                if _argocdNamespace:
                    namespace = _argocdNamespace
                if _argocdProviderConfigRef:
                    providerConfigRef = _argocdProviderConfigRef
                if _argocdServer:
                    server = _argocdServer
            }
        }
    }
