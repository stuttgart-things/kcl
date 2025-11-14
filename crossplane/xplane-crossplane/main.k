import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as k8s

# --- Get XR spec fields with environment variable style defaults ---
configName = option("params")?.oxr?.spec?.name or "crossplane-deployment"
targetNamespace = option("params")?.oxr?.spec?.targetNamespace or "crossplane-system"
version = option("params")?.oxr?.spec?.version or "1.20.0"
clusterName = option("params")?.oxr?.spec?.clusterName or "kind"

# Crossplane specific configuration
args = option("params")?.oxr?.spec?.args or [
    "--debug",
    "--enable-usages",
    "--enable-external-secret-stores"
]

# Provider packages with version defaults matching environment variables
helmProviderVersion = option("params")?.oxr?.spec?.helmProviderVersion or "v0.21.0"
k8sProviderVersion = option("params")?.oxr?.spec?.k8sProviderVersion or "v0.18.0"

providers = option("params")?.oxr?.spec?.providers or [
    "xpkg.upbound.io/crossplane-contrib/provider-helm:{}".format(helmProviderVersion),
    "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:{}".format(k8sProviderVersion)
]

# Boolean flag for Terraform provider with explicit False checking
_deployTerraformProviderValue = option("params")?.oxr?.spec?.deployTerraformProvider
deployTerraformProvider = True if _deployTerraformProviderValue == True else False

# Terraform provider configuration with environment variable style defaults
terraformProviderVersion = option("params")?.oxr?.spec?.terraformProviderVersion or "v1.0.0"
terraformProviderImage = option("params")?.oxr?.spec?.terraformProviderImage or "ghcr.io/stuttgart-things/sthings-cptf:1.12.0"
terraformS3SecretName = option("params")?.oxr?.spec?.terraformS3SecretName or "s3"

terraformConfig = option("params")?.oxr?.spec?.terraformConfig or {
    configName = "terraform-runtime-config"
    s3SecretName = terraformS3SecretName
terraformProviderVersion = option("params")?.oxr?.spec?.terraformProviderVersion or "v1.0.0"
    poll = "10m"
    reconcileRate = "10"
    package = "xpkg.upbound.io/crossplane-contrib/provider-terraform"
    version = terraformProviderVersion
}

# Secrets for Terraform provider (if needed) - safe handling
_secretsProvided = option("params")?.oxr?.spec or {}
secrets = _secretsProvided.secrets if "secrets" in _secretsProvided and _secretsProvided else {}

# Create a safe resource name from cluster name (replace dots, underscores with dashes)
safeClusterName = clusterName.replace(".", "-").replace("_", "-")

# Namespace object for Crossplane
namespace_object = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "namespace-${targetNamespace.replace('_', '-').replace('.', '-')}-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "crossplane-namespace-${targetNamespace.replace('_', '-').replace('.', '-')}-${safeClusterName}"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Namespace"
                metadata = {
                    name = targetNamespace
                    labels = {
                        "app.kubernetes.io/managed-by" = "crossplane"
                        "crossplane.io/config" = configName
                        "crossplane.io/cluster" = safeClusterName
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

# Main Crossplane deployment
crossplane_release = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "crossplane-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "crossplane-{}-{}".format(configName, safeClusterName)
        }
    }
    spec = {
        providerConfigRef = {
            name = clusterName
        }
        forProvider = {
            chart = {
                name = "crossplane"
                repository = "https://charts.crossplane.io/stable"
                version = version
            }
            namespace = targetNamespace
            wait = True
            waitTimeout = "10m"
            values = {
                args = args
                provider = {
                    packages = providers
                }
            }
        }
    }
}

# Terraform Provider DeploymentRuntimeConfig - Wrapped in Object
terraform_deployment_runtime_config = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "terraform-runtime-config-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "terraform-deployment-runtime-config-{}-{}".format(configName, safeClusterName)
        }
    }
    spec = {
        providerConfigRef = {
            name = clusterName
        }
        forProvider = {
            manifest = {
                apiVersion = "pkg.crossplane.io/v1beta1"
                kind = "DeploymentRuntimeConfig"
                metadata = {
                    name = terraformConfig.configName
                    namespace = targetNamespace
                }
                spec = {
                    deploymentTemplate = {
                        spec = {
                            selector = {}
                            strategy = {}
                            template = {
                                spec = {
                                    containers = [
                                        {
                                            name = "package-runtime"
                                            image = terraformConfig.image
                                            args = [
                                                "-d",
                                                "--poll={}".format(terraformConfig.poll),
                                                "--max-reconcile-rate={}".format(terraformConfig.reconcileRate)
                                            ]
                                            envFrom = [
                                                {
                                                    secretRef = {
                                                        name = terraformConfig.s3SecretName
                                                    }
                                                }
                                            ]
                                            resources = {}
                                        }
                                    ]
                                }
                            }
                        }
                    }
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# Terraform Provider - Wrapped in Object
terraform_provider_resource = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "terraform-provider-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "terraform-provider-{}-{}".format(configName, safeClusterName)
        }
    }
    spec = {
        providerConfigRef = {
            name = clusterName
        }
        forProvider = {
            manifest = {
                apiVersion = "pkg.crossplane.io/v1"
                kind = "Provider"
                metadata = {
                    name = "provider-terraform"
                    namespace = targetNamespace
                }
                spec = {
                    package = "{}:{}".format(terraformConfig.package, terraformConfig.version)
                    runtimeConfigRef = {
                        name = terraformConfig.configName
                    }
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# Secret management for Terraform - Generate Secret objects for each secret
secret_objects = [
    k8s.Object {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "secret-${secretName}-${safeClusterName}"
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "terraform-secret-${secretName}-${safeClusterName}"
            }
        }
        spec = {
            providerConfigRef = {
                name = clusterName
            }
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = secretName
                        namespace = secretConfig.namespace
                        labels = {
                            "app.kubernetes.io/managed-by" = "crossplane"
                            "crossplane.io/config" = configName
                            "crossplane.io/cluster" = safeClusterName
                        }
                    }
                    type = "Opaque"
                    stringData = secretConfig.kvs
                }
            }
            managementPolicies = ["*"]
        }
    }
    for secretName, secretConfig in secrets
]

# Generate items conditionally - single line syntax
terraform_resources = [terraform_deployment_runtime_config, terraform_provider_resource] + secret_objects if deployTerraformProvider else []
items = [namespace_object, crossplane_release] + terraform_resources
