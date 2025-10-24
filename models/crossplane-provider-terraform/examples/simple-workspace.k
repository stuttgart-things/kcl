# Example: Simple Terraform Workspace
# This example demonstrates how to create Terraform workspaces using the module

import ..main as terraform

# Example 1: Simple Git-based Terraform workspace
simple_workspace = terraform.gitTerraformWorkspace(
    "my-terraform-workspace",
    "https://github.com/stuttgart-things/terraform-modules.git",
    "aws/ec2-instance",
    {
        "instance_type": "t3.micro"
        "region": "eu-central-1"
    }
)

# Example 2: Inline Terraform workspace with HCL
inline_workspace = terraform.inlineTerraformWorkspace(
    "inline-workspace",
    """
resource "random_id" "example" {
  byte_length = 8
}

output "random_id" {
  value = random_id.example.hex
}
    """,
    "HCL",
    {}
)

# Example 3: Advanced workspace with full configuration
advanced_workspace = terraform.generateTerraformWorkspace(terraform.TerraformWorkspace {
    name = "advanced-workspace"
    namespace = "terraform-system"
    labels = {
        "app": "terraform"
        "component": "workspace"
        "environment": "production"
    }
    annotations = {
        "description": "Advanced Terraform workspace with full configuration"
    }

    source = "Remote"
    module = "https://github.com/stuttgart-things/terraform-modules.git//kubernetes/namespace"

    variables = {
        "namespace_name": "my-app"
        "labels": "{\"environment\":\"production\",\"team\":\"platform\"}"
    }

    environmentVariables = [
        terraform.TerraformEnvVar {
            name = "TF_VAR_cluster_endpoint"
            secretRef = terraform.ResourceReference {
                name = "cluster-config"
                namespace = "terraform-system"
                key = "endpoint"
            }
        }
    ]

    variableFiles = [
        terraform.TerraformVarFile {
            source = "ConfigMapKey"
            format = "HCL"
            configMapRef = terraform.ResourceReference {
                name = "terraform-vars"
                namespace = "terraform-system"
                key = "variables.tfvars"
            }
        }
    ]

    initArgs = ["-upgrade"]
    planArgs = ["-detailed-exitcode"]
    applyArgs = ["-auto-approve"]

    providerConfigRef = "terraform-provider-config"

    connectionSecret = terraform.TerraformConnectionSecret {
        name = "terraform-outputs"
        namespace = "terraform-system"
    }

    managementPolicies = ["Create", "Update", "Delete"]
    deletionPolicy = "Delete"
    enableTerraformCLILogging = True
})

# Example 4: Workspace with secrets for sensitive outputs
secret_workspace = terraform.secretTerraformWorkspace(
    "secret-workspace",
    "https://github.com/stuttgart-things/terraform-modules.git//aws/rds",
    "database-credentials",
    "database-system",
    {
        "db_name": "myapp"
        "db_instance_class": "db.t3.micro"
    }
)

# Render all examples
workspaces = simple_workspace + inline_workspace + advanced_workspace + secret_workspace
