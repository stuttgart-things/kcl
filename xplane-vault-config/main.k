import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as k8s

# --- Get XR spec fields ---
configName = option("params")?.oxr?.spec?.name or "vault-config"
namespaceCsi = option("params")?.oxr?.spec?.namespaceCsi or "secrets-store-csi"
namespaceVso = option("params")?.oxr?.spec?.namespaceVso or "vault-secrets-operator"
namespaceEso = option("params")?.oxr?.spec?.namespaceEso or "external-secrets"
clusterName = option("params")?.oxr?.spec?.clusterName or "default"

# Chart versions
csiChartVersion = option("params")?.oxr?.spec?.csiChartVersion or "1.5.4"
vsoChartVersion = option("params")?.oxr?.spec?.vsoChartVersion or "1.0.1"
esoChartVersion = option("params")?.oxr?.spec?.esoChartVersion or "0.20.3"

# K8s Auth configurations - independent from Helm releases
k8sAuths = option("params")?.oxr?.spec?.k8sAuths or [
    {"name": "vault-auth-{}".format(configName), "namespace": "default"}
]

# Boolean flags with explicit False checking
_csiEnabledValue = option("params")?.oxr?.spec?.csiEnabled
csiEnabled = False if _csiEnabledValue == False else True

_vsoEnabledValue = option("params")?.oxr?.spec?.vsoEnabled
vsoEnabled = False if _vsoEnabledValue == False else True

_esoEnabledValue = option("params")?.oxr?.spec?.esoEnabled
esoEnabled = False if _esoEnabledValue == False else True

# Secrets Store CSI Driver Release
csiRelease = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "secrets-store-csi-driver-${configName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-csi-{}".format(configName)
        }
    }
    spec = {
        providerConfigRef: {
            name = clusterName
        }
        forProvider: {
            chart: {
                name = "secrets-store-csi-driver"
                repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
                version = csiChartVersion
            }
            namespace = namespaceCsi
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
        name = "vault-secrets-operator-${configName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-vso-{}".format(configName)
        }
    }
    spec = {
        providerConfigRef: {
            name = clusterName
        }
        forProvider: {
            chart: {
                name = "vault-secrets-operator"
                repository = "https://helm.releases.hashicorp.com"
                version = vsoChartVersion
            }
            namespace = namespaceVso
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

# External Secrets Operator Release
esoRelease = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "external-secrets-${configName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-eso-{}".format(configName)
        }
    }
    spec = {
        providerConfigRef: {
            name = clusterName
        }
        forProvider: {
            chart: {
                name = "external-secrets"
                repository = "https://charts.external-secrets.io"
                version = esoChartVersion
            }
            namespace = namespaceEso
            values: {
                "external-secrets": {
                    installCRDs: True
                    replicaCount: 1
                    serviceMonitor: {
                        enabled: True
                    }
                }
            }
        }
    }
}

# K8s Auth resources are generated from the independent k8sAuths configuration

# Generate ServiceAccount objects for each auth
serviceAccounts = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "serviceaccount-${auth.name}"
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-serviceaccount-${auth.name}"
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
            providerConfigRef = {
                name = clusterName
            }
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
            name = "secret-${auth.name}"
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-secret-${auth.name}"
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
            providerConfigRef = {
                name = clusterName
            }
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
            name = "clusterrolebinding-${auth.name}"
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-clusterrolebinding-${auth.name}"
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
            providerConfigRef = {
                name = clusterName
            }
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
            name = "token-reader-${auth.name}"
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-token-reader-{}".format(auth.name)
            }
        }
        spec = {
            deletionPolicy = "Delete"
            managementPolicies = ["Observe"]  # Important: Only observe, don't manage!
            providerConfigRef = {
                name = clusterName
            }
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
                    toConnectionSecretKey = "token"
                }
            ]
            writeConnectionSecretToRef = {
                name = "vault-token-{}".format(auth.name)  # Connection secret with token
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

# Generate Namespace objects for all unique namespaces
namespaces = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "namespace-${ns.replace('_', '-').replace('.', '-')}"
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "vault-namespace-${ns.replace('_', '-').replace('.', '-')}"
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
                            "vault.crossplane.io/config" = name
                        }
                    }
                }
            }
            managementPolicies = ["*"]
            providerConfigRef = {
                name = clusterName
            }
        }
    }
    for ns in uniqueNamespaces if ns != "default"  # Skip creating 'default' namespace
]

# Generate items conditionally - Namespaces first, then Helm releases + Kubernetes resources + Token readers
items = namespaces + ([csiRelease] if csiEnabled else []) + ([vsoRelease] if vsoEnabled else []) + ([esoRelease] if esoEnabled else []) + serviceAccounts + secrets + clusterRoleBindings + tokenReaders
