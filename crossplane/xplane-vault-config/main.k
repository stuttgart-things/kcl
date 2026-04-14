import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as k8s

# --- Null-safe param accessors (Crossplane v2 namespaced-friendly) ---
_params = option("params") or {}
_oxr = _params?.oxr or {}
_spec = _oxr?.spec or {}
_meta = _oxr?.metadata or {}

configName = _spec?.name or "vault-config"
namespaceCsi = _spec?.namespaceCsi or "secrets-store-csi"
namespaceVso = _spec?.namespaceVso or "vault-secrets-operator"
namespaceEso = _spec?.namespaceEso or "external-secrets"
clusterName = _spec?.clusterName or "default"

# Namespace for composed resources — v2 namespaced XRs require this on every
# Release/Object. Falls back to the XR's own metadata.namespace.
_namespace = _spec?.namespace or _meta?.namespace or "default"

# Provider config reference. provider-helm and provider-kubernetes still ship
# a cluster-scoped ProviderConfig (no ClusterProviderConfig kind), so only
# `name` is required here even when consumed by a v2 namespaced XR.
_providerConfigName = _spec?.providerConfigName or clusterName

_providerConfigRef = {
    name = _providerConfigName
}

# vcluster flag for special handling
isVcluster = True if _spec?.isVcluster == True else False

# Chart versions
csiChartVersion = _spec?.csiChartVersion or "1.5.4"
vsoChartVersion = _spec?.vsoChartVersion or "1.0.1"
esoChartVersion = _spec?.esoChartVersion or "0.11.3"

# K8s Auth configurations - independent from Helm releases
k8sAuths = _spec.k8sAuths if "k8sAuths" in _spec else [
    {"name": "vault-auth-{}".format(configName), "namespace": _namespace}
]

# Boolean flags with explicit False checking
csiEnabled = False if _spec?.csiEnabled == False else True
vsoEnabled = False if _spec?.vsoEnabled == False else True
esoEnabled = False if _spec?.esoEnabled == False else True

# Create a safe resource name from cluster name (replace dots, underscores with dashes)
safeClusterName = clusterName.replace(".", "-").replace("_", "-")

# Secrets Store CSI Driver Release
csiRelease = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "vault-csi-${safeClusterName}"
        namespace = _namespace
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-csi-{}-{}".format(configName, safeClusterName)
        }
    }
    spec = {
        providerConfigRef: _providerConfigRef
        forProvider: {
            chart: {
                name = "secrets-store-csi-driver"
                repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
                version = csiChartVersion
            }
            namespace = namespaceCsi
            wait: True
            waitTimeout: "10m"
            values: {
                "secrets-store-csi-driver": {
                    enableSecretRotation: True
                    linux: {
                        enabled: True
                    }
                }
            }
        }
    }
}

# Vault Secrets Operator Release
vsoRelease = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "vso-${safeClusterName}"
        namespace = _namespace
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-vso-{}-{}".format(configName, safeClusterName)
        }
    }
    spec = {
        providerConfigRef: _providerConfigRef
        forProvider: {
            chart: {
                name = "vault-secrets-operator"
                repository = "https://helm.releases.hashicorp.com"
                version = vsoChartVersion
            }
            namespace = namespaceVso
            waitTimeout: "10m"
            values: {
                "vault-secrets-operator": {
                    defaultVaultConnection: {
                        enabled: True
                    }
                    controller: {
                        manager: {
                            clientCache: {
                                persistenceModel: "direct-encrypted"
                            }
                        }
                    }
                }
            }
        }
    }
}

# External Secrets Operator Release - vcluster optimized with cluster-aware naming
# Conditionally disable probes for vcluster
_esoProbeConfig = {
    "enabled": False
} if isVcluster else {}

esoRelease = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "eso-${safeClusterName}"
        namespace = _namespace
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-eso-{}-{}".format(configName, safeClusterName)
        }
    }
    spec = {
        providerConfigRef: _providerConfigRef
        forProvider: {
            chart: {
                name = "external-secrets"
                repository = "https://charts.external-secrets.io"
                version = esoChartVersion
            }
            namespace = namespaceEso
            wait: True
            waitTimeout: "10m"
            values: {
                installCRDs: True

                # Webhook configuration
                webhook: {
                    port: 10250
                    create: True
                    certCheckInterval: "5m"
                    lookaheadInterval: "168h"
                }

                # Cert controller - conditionally disable probes for vcluster
                certController: {
                    create: True
                    requeueInterval: "5m"
                    readinessProbe: _esoProbeConfig if isVcluster else {
                        enabled: True
                    }
                    livenessProbe: _esoProbeConfig if isVcluster else {
                        enabled: True
                    }
                    resources: {
                        limits: {
                            cpu: "200m"
                            memory: "256Mi"
                        }
                        requests: {
                            cpu: "50m"
                            memory: "128Mi"
                        }
                    }
                }

                # Main controller - also disable probes for vcluster
                replicaCount: 1
                readinessProbe: _esoProbeConfig if isVcluster else {
                    enabled: True
                }
                livenessProbe: _esoProbeConfig if isVcluster else {
                    enabled: True
                }
                resources: {
                    limits: {
                        cpu: "200m"
                        memory: "256Mi"
                    }
                    requests: {
                        cpu: "50m"
                        memory: "128Mi"
                    }
                }

                # Monitoring
                serviceMonitor: {
                    enabled: True
                }

                # Logging
                logLevel: "info"
            }
        }
    }
}

# K8s Auth resources are generated from the independent k8sAuths configuration
# Now include cluster name in resource naming

# Generate ServiceAccount objects for each auth
serviceAccounts = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "serviceaccount-${auth.name}-${safeClusterName}"
            namespace = _namespace
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-serviceaccount-${auth.name}-${safeClusterName}"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "ServiceAccount"
                    metadata = {
                        name = auth.name
                        namespace = auth.namespace
                    }
                    automountServiceAccountToken = True
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = _providerConfigRef
        }
    }
    for auth in k8sAuths
]

# Generate Secret objects for each auth
secrets = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "secret-${auth.name}-${safeClusterName}"
            namespace = _namespace
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-secret-${auth.name}-${safeClusterName}"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = auth.name
                        namespace = auth.namespace
                        annotations = {
                            "kubernetes.io/service-account.name" = auth.name
                            "kubernetes.io/service-account.namespace" = auth.namespace
                        }
                    }
                    type = "kubernetes.io/service-account-token"
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = _providerConfigRef
        }
    }
    for auth in k8sAuths
]

# Generate ClusterRoleBinding objects for each auth
clusterRoleBindings = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "clusterrolebinding-${auth.name}-${safeClusterName}"
            namespace = _namespace
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-clusterrolebinding-${auth.name}-${safeClusterName}"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "rbac.authorization.k8s.io/v1"
                    kind = "ClusterRoleBinding"
                    metadata = {
                        name = auth.name
                    }
                    roleRef = {
                        apiGroup = "rbac.authorization.k8s.io"
                        kind = "ClusterRole"
                        name = "system:auth-delegator"
                    }
                    subjects = [{
                        kind = "ServiceAccount"
                        name = auth.name
                        namespace = auth.namespace
                    }]
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = _providerConfigRef
        }
    }
    for auth in k8sAuths
]

# Generate Token Reader objects for each auth - reads token from service account secrets
tokenReaders = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "token-reader-${auth.name}-${safeClusterName}"
            namespace = _namespace
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-token-reader-{}-{}".format(auth.name, safeClusterName)
            }
        }
        spec = {
            deletionPolicy = "Delete"
            managementPolicies = ["Observe"]  # Important: Only observe, don't manage!
            providerConfigRef = _providerConfigRef
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = auth.name
                        namespace = auth.namespace
                    }
                }
            }
            connectionDetails = [
                {
                    apiVersion = "v1"
                    kind = "Secret"
                    name = auth.name
                    namespace = auth.namespace
                    fieldPath = "data.token"
                    toConnectionSecretKey = "token" # pragma: allowlist secret
                }
            ]
            writeConnectionSecretToRef = {
                name = "vault-token-{}-{}".format(auth.name, safeClusterName)  # Connection secret with token and cluster
                namespace = "crossplane-system"
            }
        }
    }
    for auth in k8sAuths
]

# Collect all unique namespaces that need to be created
_helmNamespaces = []
_helmNamespaces += [namespaceCsi] if csiEnabled else []
_helmNamespaces += [namespaceVso] if vsoEnabled else []
_helmNamespaces += [namespaceEso] if esoEnabled else []

_authNamespaces = [auth.namespace for auth in k8sAuths]
_allNamespaces = _helmNamespaces + _authNamespaces

# Remove duplicates - simple approach with list comprehension
_uniqueMap = {ns: None for ns in _allNamespaces}
uniqueNamespaces = [ns for ns in _uniqueMap]

# Generate Namespace objects for all unique namespaces - include cluster name
namespaces = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "namespace-${ns.replace('_', '-').replace('.', '-')}-${safeClusterName}"
            namespace = _namespace
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-namespace-${ns.replace('_', '-').replace('.', '-')}-${safeClusterName}"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Namespace"
                    metadata = {
                        name = ns
                        labels = {
                            "app.kubernetes.io/managed-by" = "crossplane"
                            "vault.crossplane.io/config" = configName
                            "vault.crossplane.io/cluster" = safeClusterName
                        }
                    }
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = _providerConfigRef
        }
    }
    for ns in uniqueNamespaces if ns != "default"  # Skip creating 'default' namespace
]

# Generate items conditionally - Namespaces first, then Helm releases + Kubernetes resources + Token readers
items = namespaces + ([csiRelease] if csiEnabled else []) + ([vsoRelease] if vsoEnabled else []) + ([esoRelease] if esoEnabled else []) + serviceAccounts + secrets + clusterRoleBindings + tokenReaders