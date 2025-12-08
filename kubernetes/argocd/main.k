import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as k8s

# --- Get XR spec fields with environment variable style defaults ---
configName = option("params")?.oxr?.spec?.name or "argocd-deployment"
targetNamespace = option("params")?.oxr?.spec?.targetNamespace or "argocd"
version = option("params")?.oxr?.spec?.version or "8.2.5"
clusterName = option("params")?.oxr?.spec?.clusterName or "kind"

# ArgoCD service configuration
serviceType = option("params")?.oxr?.spec?.serviceType or "ClusterIP"
nodePortHttp = option("params")?.oxr?.spec?.nodePortHttp

# Ingress configuration
_enableIngressValue = option("params")?.oxr?.spec?.enableIngress
enableIngress = True if _enableIngressValue == True else False
hostname = option("params")?.oxr?.spec?.hostname or "argocd"
domain = option("params")?.oxr?.spec?.domain or "example.com"
ingressClassName = option("params")?.oxr?.spec?.ingressClassName or "nginx"

# Certificate configuration
_createCertificateResourceValue = option("params")?.oxr?.spec?.createCertificateResource
createCertificateResource = True if _createCertificateResourceValue == True else False
issuerName = option("params")?.oxr?.spec?.issuerName or "selfsigned"
issuerKind = option("params")?.oxr?.spec?.issuerKind or "ClusterIssuer"
certificateSecretName = option("params")?.oxr?.spec?.certificateSecretName or "argocd-server-tls"

# Admin credentials
adminPassword = option("params")?.oxr?.spec?.adminPassword or ""
adminPasswordMTime = option("params")?.oxr?.spec?.adminPasswordMTime or ""

# AVP (ArgoCD Vault Plugin) configuration
_enableAvpValue = option("params")?.oxr?.spec?.enableAvp
enableAvp = True if _enableAvpValue == True else False
vaultAddr = option("params")?.oxr?.spec?.vaultAddr or ""
vaultNamespace = option("params")?.oxr?.spec?.vaultNamespace or ""
vaultRoleID = option("params")?.oxr?.spec?.vaultRoleID or ""
vaultSecretID = option("params")?.oxr?.spec?.vaultSecretID or ""
imageAvp = option("params")?.oxr?.spec?.imageAvp or "quay.io/argoproj/argocd-vault-plugin:latest"
imageHelmfile = option("params")?.oxr?.spec?.imageHelmfile or "ghcr.io/helmfile/helmfile:latest"

# Create a safe resource name from cluster name (replace dots, underscores with dashes)
safeClusterName = clusterName.replace(".", "-").replace("_", "-")

# Namespace object for ArgoCD
namespace_object = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "namespace-${targetNamespace.replace('_', '-').replace('.', '-')}-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "argocd-namespace-${targetNamespace.replace('_', '-').replace('.', '-')}-${safeClusterName}"
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

# AVP Secret configuration
avp_secret = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "argocd-vault-plugin-credentials-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "argocd-vault-plugin-credentials-${safeClusterName}"
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
                    name = "argocd-vault-plugin-credentials"
                    namespace = targetNamespace
                    labels = {
                        "app.kubernetes.io/managed-by" = "crossplane"
                        "crossplane.io/config" = configName
                        "crossplane.io/cluster" = safeClusterName
                    }
                }
                type = "Opaque"
                stringData = {
                    "AVP_TYPE" = "vault"
                    "TYPE" = "vault"
                    "AVP_AUTH_TYPE" = "approle"
                    "AVP_VAULT_ADDR" = vaultAddr
                    "VAULT_ADDR" = vaultAddr
                    "VAULT_NAMESPACE" = vaultNamespace
                    "AVP_ROLE_ID" = vaultRoleID
                    "AVP_SECRET_ID" = vaultSecretID
                    "VAULT_SKIP_VERIFY" = "true"
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# Build helm values dynamically
_baseValues = {
    server = {
        service = {
            type = serviceType
        }
    }
    configs = {
        secret = {
            argocdServerAdminPassword = adminPassword
            argocdServerAdminPasswordMtime = adminPasswordMTime
        }
    }
}

# Add nodePortHttp if provided
_serviceWithNodePort = {
    server = {
        service = {
            type = serviceType
            nodePortHttp = nodePortHttp
        }
    }
} if nodePortHttp else _baseValues

# Add ingress configuration if enabled
_valuesWithIngress = _serviceWithNodePort | {
    server = {
        ingress = {
            enabled = True
            annotations = {
                "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
                "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
            } | ({"cert-manager.io/{}".format(issuerKind) = issuerName} if not createCertificateResource else {})
            ingressClassName = ingressClassName
            hostname = "{}.{}".format(hostname, domain)
            tls = True
        }
    }
} if enableIngress else _serviceWithNodePort

# Add AVP plugin configuration if enabled
_valuesWithAvp = _valuesWithIngress | {
    configs = {
        cmp = {
            create = True
            plugins = {
                "argocd-vault-plugin" = {
                    allowConcurrency = True
                    discover = {
                        find = {
                            command = ["sh", "-c", "find . -name '*.yaml' | xargs -I {} grep \"<path\\|avp\\.kubernetes\\.io\" {}"]
                        }
                    }
                    generate = {
                        command = ["argocd-vault-plugin", "generate", "."]
                    }
                    lockRepo = False
                }
                "argocd-vault-plugin-kustomize" = {
                    allowConcurrency = True
                    discover = {
                        find = {
                            command = ["find", ".", "-name", "kustomization.yaml"]
                        }
                    }
                    generate = {
                        command = ["sh", "-c", "kustomize build . | argocd-vault-plugin generate -"]
                    }
                    lockRepo = False
                }
                "argocd-vault-plugin-helm" = {
                    allowConcurrency = True
                    discover = {
                        find = {
                            command = ["sh", "-c", "find . -name 'Chart.yaml' && find . -name 'values.yaml'"]
                        }
                    }
                    generate = {
                        command = ["sh", "-c", 'helm template "$ARGOCD_APP_NAME" -f <(echo "$ARGOCD_ENV_HELM_VALUES") --include-crds . -n $ARGOCD_APP_NAMESPACE | argocd-vault-plugin generate -']
                    }
                    lockRepo = False
                }
                "helmfile" = {
                    allowConcurrency = True
                    discover = {
                        fileName = "helmfile.yaml"
                    }
                    generate = {
                        command = ["bash", "-c", "if [[ -v ENV_NAME ]]; then\n  helmfile -n \"$ARGOCD_APP_NAMESPACE\" -e $ENV_NAME template --include-crds -q\nelif [[ -v ARGOCD_ENV_ENV_NAME ]]; then\n  helmfile -n \"$ARGOCD_APP_NAMESPACE\" -e \"$ARGOCD_ENV_ENV_NAME\" template --include-crds -q\nelse\n  helmfile -n \"$ARGOCD_APP_NAMESPACE\" template --include-crds -q\nfi"]
                    }
                    lockRepo = False
                }
            }
        }
    }
    repoServer = {
        extraContainers = [
            {
                name = "helmfile"
                image = imageHelmfile
                command = ["/var/run/argocd/argocd-cmp-server"]
                env = [
                    {name = "HELM_CACHE_HOME", value = "/tmp/helm/cache"},
                    {name = "HELM_CONFIG_HOME", value = "/tmp/helm/config"},
                    {name = "HELMFILE_CACHE_HOME", value = "/tmp/helmfile/cache"},
                    {name = "HELMFILE_TEMPDIR", value = "/tmp/helmfile/tmp"}
                ]
                securityContext = {
                    runAsNonRoot = True
                    runAsUser = 999
                }
                volumeMounts = [
                    {mountPath = "/var/run/argocd", name = "var-files"},
                    {mountPath = "/home/argocd/cmp-server/plugins", name = "plugins"},
                    {mountPath = "/home/argocd/cmp-server/config/plugin.yaml", subPath = "helmfile.yaml", name = "argocd-cmp-cm"},
                    {mountPath = "/tmp", name = "cmp-tmp"}
                ]
            },
            {
                name = "argocd-vault-plugin"
                command = ["/var/run/argocd/argocd-cmp-server"]
                image = imageAvp
                envFrom = [
                    {secretRef = {name = "argocd-vault-plugin-credentials"}}
                ]
                securityContext = {
                    runAsNonRoot = True
                    runAsUser = 999
                }
                volumeMounts = [
                    {mountPath = "/var/run/argocd", name = "var-files"},
                    {mountPath = "/home/argocd/cmp-server/plugins", name = "plugins"},
                    {mountPath = "/tmp", name = "tmp"},
                    {mountPath = "/home/argocd/cmp-server/config/plugin.yaml", subPath = "argocd-vault-plugin.yaml", name = "argocd-cmp-cm"}
                ]
            },
            {
                name = "argocd-vault-plugin-helm"
                command = ["/var/run/argocd/argocd-cmp-server"]
                image = imageAvp
                envFrom = [
                    {secretRef = {name = "argocd-vault-plugin-credentials"}}
                ]
                securityContext = {
                    runAsNonRoot = True
                    runAsUser = 999
                }
                volumeMounts = [
                    {mountPath = "/var/run/argocd", name = "var-files"},
                    {mountPath = "/home/argocd/cmp-server/plugins", name = "plugins"},
                    {mountPath = "/tmp", name = "tmp"},
                    {mountPath = "/home/argocd/cmp-server/config/plugin.yaml", subPath = "argocd-vault-plugin-helm.yaml", name = "argocd-cmp-cm"}
                ]
            },
            {
                name = "argocd-vault-plugin-kustomize"
                command = ["/var/run/argocd/argocd-cmp-server"]
                image = imageAvp
                envFrom = [
                    {secretRef = {name = "argocd-vault-plugin-credentials"}}
                ]
                securityContext = {
                    runAsNonRoot = True
                    runAsUser = 999
                }
                volumeMounts = [
                    {mountPath = "/var/run/argocd", name = "var-files"},
                    {mountPath = "/home/argocd/cmp-server/plugins", name = "plugins"},
                    {mountPath = "/tmp", name = "tmp"},
                    {mountPath = "/home/argocd/cmp-server/config/plugin.yaml", subPath = "argocd-vault-plugin-kustomize.yaml", name = "argocd-cmp-cm"}
                ]
            }
        ]
        volumes = [
            {name = "argocd-cmp-cm", configMap = {name = "argocd-cmp-cm"}},
            {name = "helmfile-tmp", emptyDir = {}},
            {name = "cmp-tmp", emptyDir = {}}
        ]
    }
} if enableAvp else _valuesWithIngress

# Final helm values
helmValues = _valuesWithAvp

# Main ArgoCD deployment
argocd_release = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "argocd-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "argocd-{}-{}".format(configName, safeClusterName)
        }
    }
    spec = {
        providerConfigRef = {
            name = clusterName
        }
        forProvider = {
            chart = {
                name = "argo-cd"
                repository = "https://argoproj.github.io/argo-helm"
                version = version
            }
            namespace = targetNamespace
            wait = True
            waitTimeout = "10m"
            values = helmValues
        }
    }
}

# Certificate resource for ArgoCD ingress TLS
certificate_resource = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "argocd-certificate-${safeClusterName}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "argocd-certificate-${safeClusterName}"
        }
    }
    spec = {
        providerConfigRef = {
            name = clusterName
        }
        forProvider = {
            manifest = {
                apiVersion = "cert-manager.io/v1"
                kind = "Certificate"
                metadata = {
                    name = "{}-ingress".format(hostname)
                    namespace = targetNamespace
                }
                spec = {
                    commonName = "{}.{}".format(hostname, domain)
                    dnsNames = ["{}.{}".format(hostname, domain)]
                    issuerRef = {
                        name = issuerName
                        kind = issuerKind
                    }
                    secretName = certificateSecretName
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# Generate items conditionally
avp_resources = [avp_secret] if enableAvp else []
certificate_resources = [certificate_resource] if createCertificateResource else []
items = [namespace_object, argocd_release] + avp_resources + certificate_resources
