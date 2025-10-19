import json

# Crossplane-compliant variable access pattern (as per .container-use specs)
name = option("params")?.oxr?.spec?.name or "vault-cluster"
namespace = option("params")?.oxr?.spec?.namespace or "vault-system"
vault_addr = option("params")?.oxr?.spec?.vaultAddr or "https://vault.example.com"
cluster_name = option("params")?.oxr?.spec?.clusterName or "dev-cluster"
context = option("params")?.oxr?.spec?.context or "default"
kubeconfig_path = option("params")?.oxr?.spec?.kubeconfigPath or "/home/user/.kube/config"
skip_tls_verify = option("params")?.oxr?.spec?.skipTlsVerify or True
csi_enabled = option("params")?.oxr?.spec?.csiEnabled or True
namespace_csi = option("params")?.oxr?.spec?.namespaceCsi or "vault"
vso_enabled = option("params")?.oxr?.spec?.vsoEnabled or True
namespace_vso = option("params")?.oxr?.spec?.namespaceVso or "vault"
k8s_auths = option("params")?.oxr?.spec?.k8sAuths or [
    {
        name = "dev"
        namespace = "default"
        token_policies = ["read-k8s"]
        token_ttl = 3600
    }
]

# Vault configuration with all variables for stuttgart-things/vault-base-setup
vault_config = {
    vault_addr = vault_addr
    cluster_name = cluster_name
    context = context
    skip_tls_verify = skip_tls_verify
    kubeconfig_path = kubeconfig_path
    csi_enabled = csi_enabled
    namespace_csi = namespace_csi
    vso_enabled = vso_enabled
    namespace_vso = namespace_vso
    k8s_auths = k8s_auths
}

# Generate Secret for Terraform variables (JSON format as required by stuttgart-things/vault-base-setup)
terraform_vars_json = json.encode(vault_config)

# Kubernetes Secret containing Terraform variables
secret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = "${name}-terraform-vars"
        namespace = namespace
    }
    type = "Opaque"
    stringData = {
        "terraform.tfvars.json" = terraform_vars_json
    }
}

# Terraform Workspace for vault-base-setup module
workspace = {
    apiVersion = "tf.crossplane.io/v1alpha1"
    kind = "Workspace"
    metadata = {
        name = name
        namespace = namespace
    }
    spec = {
        forProvider = {
            source = "Remote"
            module = "https://github.com/stuttgart-things/vault-base-setup"
            varFiles = [
                {
                    source = "SecretKey"
                    secretKeyRef = {
                        namespace = namespace
                        name = "${name}-terraform-vars"
                        key = "terraform.tfvars.json"
                    }
                    format = "JSON"
                }
            ]
        }
        writeConnectionSecretsToRef = {
            namespace = namespace
        }
    }
}

# Alternative Terraform Workspace with inline vars (cleaner approach)
workspace_inline = {
    apiVersion = "tf.crossplane.io/v1alpha1"
    kind = "Workspace"
    metadata = {
        name = "${name}-inline"
        namespace = namespace
    }
    spec = {
        forProvider = {
            source = "Remote"
            module = "https://github.com/stuttgart-things/vault-base-setup"
            # Variables can be specified inline
            vars = [
                {
                    key = "vault_addr"
                    value = vault_addr
                },
                {
                    key = "cluster_name" 
                    value = cluster_name
                },
                {
                    key = "context"
                    value = context
                },
                {
                    key = "skip_tls_verify"
                    value = str(skip_tls_verify)
                },
                {
                    key = "kubeconfig_path"
                    value = kubeconfig_path
                },
                {
                    key = "csi_enabled"
                    value = str(csi_enabled)
                },
                {
                    key = "namespace_csi"
                    value = namespace_csi
                },
                {
                    key = "vso_enabled"
                    value = str(vso_enabled)
                },
                {
                    key = "namespace_vso"
                    value = namespace_vso
                },
                {
                    key = "k8s_auths"
                    value = json.encode(k8s_auths)
                }
            ]
        }
        writeConnectionSecretsToRef = {
            namespace = namespace
        }
    }
}

# Output all resources
manifests = [secret, workspace, workspace_inline]