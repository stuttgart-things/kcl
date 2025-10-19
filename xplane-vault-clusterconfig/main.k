import json

# Crossplane-compliant variable access pattern (as per .container-use specs)
name = option("params")?.oxr?.spec?.name or "vault-cluster"
namespace = option("params")?.oxr?.spec?.namespace or "vault-system"
vault_addr = option("params")?.oxr?.spec?.vaultAddr or "https://vault.example.com"
cluster_name = option("params")?.oxr?.spec?.clusterName or "dev-cluster"
context = option("params")?.oxr?.spec?.context or "default"
kubeconfig_path = option("params")?.oxr?.spec?.kubeconfigPath or "/home/user/.kube/config"

# Vault configuration with safe navigation and defaults
vault_config = {
    vault_addr = vault_addr
    cluster_name = cluster_name
    context = context
    kubeconfig_path = kubeconfig_path
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

# Output all resources
[secret, workspace]