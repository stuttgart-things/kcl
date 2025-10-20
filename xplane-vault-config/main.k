# XPlane Vault Config - Helm Releases for CSI and VSO
# Following Container-Use Crossplane-compliant variable patterns

# Crossplane-compliant variable access pattern (as per .container-use specs)
name = option("params")?.oxr?.spec?.name or "vault-config"
namespace_csi = option("params")?.oxr?.spec?.namespaceCsi or "secrets-store-csi"
namespace_vso = option("params")?.oxr?.spec?.namespaceVso or "vault-secrets-operator"
csi_enabled = option("params")?.oxr?.spec?.csiEnabled or True
vso_enabled = option("params")?.oxr?.spec?.vsoEnabled or True
vso_atomic = option("params")?.oxr?.spec?.vsoAtomic or True
vso_wait = option("params")?.oxr?.spec?.vsoWait or True

# CSI Driver Helm Release - Secrets Store CSI Driver
csi_helm_release = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "${name}-secrets-store-csi-driver"
        labels = {
            "app.kubernetes.io/name" = "secrets-store-csi-driver"
            "app.kubernetes.io/component" = "csi-driver"
        }
    }
    spec = {
        providerConfigRef = {
            name = "default"
        }
        forProvider = {
            chart = {
                name = "secrets-store-csi-driver"
                repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
                version = "1.4.0"
            }
            namespace = namespace_csi
            values = {
                # Enable secrets store CSI driver
                enableSecretRotation = True
                rotationPollInterval = "30s"
                # Additional CSI driver settings
                linux = {
                    enabled = True
                }
                windows = {
                    enabled = False
                }
            }
        }
        writeConnectionSecretsToRef = {
            namespace = namespace_csi
        }
    }
} if csi_enabled else {}

# VSO Helm Release - Vault Secrets Operator
vso_helm_release = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "${name}-vault-secrets-operator"
        labels = {
            "app.kubernetes.io/name" = "vault-secrets-operator"
            "app.kubernetes.io/component" = "secrets-operator"
        }
    }
    spec = {
        providerConfigRef = {
            name = "default"
        }
        forProvider = {
            chart = {
                name = "vault-secrets-operator"
                repository = "https://helm.releases.hashicorp.com"
                version = "0.10.0"
            }
            namespace = namespace_vso
            values = {
                # Vault Secrets Operator configuration
                defaultVaultConnection = {
                    enabled = True
                }
                controller = {
                    manager = {
                        clientCache = {
                            persistenceModel = "direct-encrypted"
                        }
                    }
                }
            }
        }
        writeConnectionSecretsToRef = {
            namespace = namespace_vso
        }
    }
} if vso_enabled else {}

# Output all helm releases (conditionally based on enabled flags)
base_manifests = []
csi_manifests = [csi_helm_release] if csi_enabled else []
vso_manifests = [vso_helm_release] if vso_enabled else []
manifests = base_manifests + csi_manifests + vso_manifests
