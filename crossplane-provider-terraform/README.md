# Crossplane Provider Terraform KCL Module

This KCL module provides resources for managing Terraform Workspaces through the Crossplane Terraform Provider. It simplifies the creation and configuration of Terraform workspaces with both simple helper functions and a full-featured configuration schema.

## 🎯 Features

- **Terraform Workspace Management**: Create and configure Terraform workspaces via Crossplane
- **Multiple Source Types**: Support for Remote Git, Inline code, and Flux sources
- **Variable Configuration**: Terraform variables, variable files, and environment variables
- **Connection Secrets**: Automatic output management through Kubernetes secrets
- **CLI Customization**: Custom Terraform CLI arguments for init, plan, apply, and destroy
- **Helper Functions**: Simplified functions for common workspace patterns
- **Full API Access**: Complete access to Crossplane Terraform Provider specification

## 📦 Installation

### As OCI Registry Package

```bash
# Add to kcl.mod dependencies
kcl mod add ghcr.io/stuttgart-things/crossplane-provider-terraform:0.1.0
```

### From Source

```bash
# Clone the KCL repository  
git clone https://github.com/stuttgart-things/kcl.git
cd kcl/crossplane-provider-terraform
```

## 🚀 Usage

### Quick Start Examples

#### 1. Simple Git-based Terraform Workspace

```kcl
import crossplane_provider_terraform as terraform

# Create a simple workspace from a Git repository
workspace = terraform.gitTerraformWorkspace(
    "my-infrastructure",
    "https://github.com/company/terraform-modules.git", 
    "aws/vpc",
    {
        "region": "us-west-2"
        "cidr_block": "10.0.0.0/16"
    }
)
```

#### 2. Inline Terraform Code

```kcl  
inline_workspace = terraform.inlineTerraformWorkspace(
    "quick-test",
    """
resource "random_pet" "example" {
  length = 3
}

output "pet_name" {
  value = random_pet.example.id
}
    """,
    "HCL",
    {}
)
```

#### 3. Workspace with Connection Secrets

```kcl
secret_workspace = terraform.secretTerraformWorkspace(
    "database-setup",
    "https://github.com/company/terraform-modules.git//database/postgres",
    "db-connection-secret",
    "production",
    {
        "db_name": "myapp"
        "instance_class": "db.t3.medium"
    }
)
```

### Advanced Configuration

#### Full Workspace Configuration

```kcl
advanced_workspace = terraform.generateTerraformWorkspace(terraform.TerraformWorkspace {
    name = "production-infrastructure"
    namespace = "terraform-system"
    labels = {
        "environment": "production"
        "team": "platform" 
        "managed-by": "crossplane"
    }
    annotations = {
        "description": "Production infrastructure managed by Terraform"
        "contact": "platform-team@company.com"
    }
    
    # Terraform configuration
    source = "Remote"
    module = "https://github.com/company/terraform-modules.git//aws/complete-setup"
    
    # Variables from multiple sources
    variables = {
        "region": "us-west-2" 
        "environment": "production"
        "cluster_name": "prod-cluster"
    }
    
    # Environment variables from secrets
    environmentVariables = [
        terraform.TerraformEnvVar {
            name = "AWS_ACCESS_KEY_ID"
            secretRef = terraform.ResourceReference {
                name = "aws-credentials"
                namespace = "terraform-system"
                key = "access-key-id"
            }
        }
        terraform.TerraformEnvVar {
            name = "AWS_SECRET_ACCESS_KEY"
            secretRef = terraform.ResourceReference {
                name = "aws-credentials"
                namespace = "terraform-system"
                key = "secret-access-key"
            }
        }
    ]
    
    # Variable files from ConfigMaps
    variableFiles = [
        terraform.TerraformVarFile {
            source = "ConfigMapKey"
            format = "HCL"
            configMapRef = terraform.ResourceReference {
                name = "terraform-variables"
                namespace = "terraform-system"
                key = "production.tfvars"
            }
        }
    ]
    
    # Terraform CLI customization
    initArgs = ["-upgrade", "-backend-config=production.hcl"]
    planArgs = ["-detailed-exitcode", "-out=tfplan"]
    applyArgs = ["-auto-approve", "tfplan"]
    destroyArgs = ["-auto-approve"]
    
    # Provider and connection configuration
    providerConfigRef = "terraform-aws-provider"
    connectionSecret = terraform.TerraformConnectionSecret {
        name = "infrastructure-outputs"
        namespace = "terraform-system"
    }
    
    # Management policies
    managementPolicies = ["Create", "Update", "Delete", "Observe"]
    deletionPolicy = "Delete"
    enableTerraformCLILogging = True
})
```

## 📚 API Reference

### Core Schemas

#### `TerraformWorkspace`
Main configuration schema for Terraform workspaces.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | ✅ | - | Workspace name |
| `namespace` | string | ❌ | `"default"` | Kubernetes namespace |
| `labels` | {str: str} | ❌ | `{}` | Resource labels |
| `annotations` | {str: str} | ❌ | `{}` | Resource annotations |
| `source` | string | ❌ | `"Remote"` | Source type: Remote, Inline, Flux |
| `module` | string | ✅ | - | Terraform module source |
| `entrypoint` | string | ❌ | `""` | Terraform init entrypoint |
| `inlineFormat` | string | ❌ | `"HCL"` | Format for inline code: HCL, JSON |
| `variables` | {str: str} | ❌ | `{}` | Terraform variables |
| `variableFiles` | [TerraformVarFile] | ❌ | `[]` | Variable files from ConfigMaps/Secrets |
| `environmentVariables` | [TerraformEnvVar] | ❌ | `[]` | Environment variables |
| `initArgs` | [str] | ❌ | `[]` | Terraform init arguments |
| `planArgs` | [str] | ❌ | `[]` | Terraform plan arguments |
| `applyArgs` | [str] | ❌ | `[]` | Terraform apply arguments |
| `destroyArgs` | [str] | ❌ | `[]` | Terraform destroy arguments |
| `providerConfigRef` | string | ❌ | `"default"` | Provider config reference |
| `connectionSecret` | TerraformConnectionSecret | ❌ | - | Output connection secret |
| `managementPolicies` | [str] | ❌ | `["*"]` | Crossplane management policies |
| `deletionPolicy` | string | ❌ | `"Delete"` | Resource deletion policy |
| `enableTerraformCLILogging` | bool | ❌ | `False` | Enable Terraform CLI logging |

#### `TerraformVarFile`
Configuration for Terraform variable files.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `source` | string | ✅ | - | Source type: ConfigMapKey, SecretKey |
| `format` | string | ❌ | `"HCL"` | File format: HCL, JSON |
| `configMapRef` | ResourceReference | ❌ | - | ConfigMap reference |
| `secretRef` | ResourceReference | ❌ | - | Secret reference |

#### `TerraformEnvVar`
Environment variable configuration.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | ✅ | - | Environment variable name |
| `value` | string | ❌ | - | Direct value |
| `configMapRef` | ResourceReference | ❌ | - | ConfigMap reference |
| `secretRef` | ResourceReference | ❌ | - | Secret reference |

### Helper Functions

#### `gitTerraformWorkspace(name, gitUrl, path, variables)`
Creates a simple Terraform workspace from a Git repository.

**Parameters:**
- `name` (string): Workspace name
- `gitUrl` (string): Git repository URL
- `path` (string): Path within repository ("" for root)
- `variables` ({str: str}): Terraform variables

#### `inlineTerraformWorkspace(name, terraformCode, format, variables)`
Creates a workspace with inline Terraform code.

**Parameters:**
- `name` (string): Workspace name  
- `terraformCode` (string): Inline Terraform code
- `format` (string): Code format (HCL/JSON)
- `variables` ({str: str}): Terraform variables

#### `secretTerraformWorkspace(name, gitUrl, secretName, secretNamespace, variables)`
Creates a workspace with connection secrets for outputs.

**Parameters:**
- `name` (string): Workspace name
- `gitUrl` (string): Git repository URL
- `secretName` (string): Connection secret name
- `secretNamespace` (string): Connection secret namespace  
- `variables` ({str: str}): Terraform variables

#### `generateTerraformWorkspace(config)`
Generates workspace from full configuration schema.

**Parameters:**
- `config` (TerraformWorkspace): Complete workspace configuration

## 🔧 Development

### Running Tests

```bash
cd crossplane-provider-terraform
kcl run tests/test_main.k
```

### Running Examples  

```bash
kcl run examples/simple-workspace.k
```

### Validating Generated Resources

```bash
# Test resource generation and validation
kcl run examples/simple-workspace.k | kubectl apply --dry-run=client -f -
```

## 🏗️ Integration

### With Crossplane Compositions

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: terraform-workspace-composition
spec:
  compositeTypeRef:
    apiVersion: example.com/v1alpha1
    kind: XTerraformWorkspace
  functions:
  - name: kcl-function
    type: function
    step: normal
    input:
      apiVersion: krm.kcl.dev/v1alpha1
      kind: KCLRun
      spec:
        source: |
          import crossplane_provider_terraform as terraform
          
          workspaces = terraform.gitTerraformWorkspace(
              option("oxr").spec.name,
              option("oxr").spec.gitUrl,
              option("oxr").spec.path or "",
              option("oxr").spec.variables or {}
          )
```

### With ArgoCD/Flux

```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: terraform-workspaces
spec:
  source:
    repoURL: https://github.com/company/infrastructure
    path: terraform-workspaces
    plugin:
      name: kcl
      env:
      - name: KCL_CONFIG
        value: |
          import crossplane_provider_terraform as terraform
          # workspace configurations...
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite: `kcl run tests/test_main.k`
6. Submit a pull request

## 📝 License

This project is licensed under the Apache License 2.0. See [LICENSE](../LICENSE) for details.

## 🔗 Related Projects

- [KCL xplane-vault-config](../xplane-vault-config/) - Vault services management module
- [Crossplane Terraform Provider](https://github.com/crossplane-contrib/provider-terraform) - Upstream provider
- [Stuttgart-Things Infrastructure](https://github.com/stuttgart-things) - Platform engineering resources

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/stuttgart-things/kcl/issues)
- **Documentation**: [Stuttgart-Things Docs](https://stuttgart-things.github.io)
- **Community**: [Stuttgart-Things Discussions](https://github.com/orgs/stuttgart-things/discussions)