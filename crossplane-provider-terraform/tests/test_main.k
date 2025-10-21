# Tests for Terraform Workspace Module

import ..main as terraform
import models.v1beta1.tf_upbound_io_v1beta1_workspace as workspace

# Test 1: Basic Git workspace generation
test_git_workspace = lambda {
    workspaces = terraform.gitTerraformWorkspace(
        "test-workspace",
        "https://github.com/example/terraform.git",
        "modules/vpc",
        {"region": "us-west-2"}
    )
    
    # Assertions
    assert len(workspaces) == 1
    assert workspaces[0].metadata.name == "test-workspace"
    assert workspaces[0].spec.forProvider.source == "Remote"
    assert workspaces[0].spec.forProvider.module == "https://github.com/example/terraform.git/modules/vpc"
    assert len(workspaces[0].spec.forProvider.vars) == 1
    assert workspaces[0].spec.forProvider.vars[0].key == "region"
    assert workspaces[0].spec.forProvider.vars[0].value == "us-west-2"
}

# Test 2: Inline workspace generation
test_inline_workspace = lambda {
    terraformCode = """
resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo hello"
  }
}
    """
    
    workspaces = terraform.inlineTerraformWorkspace(
        "inline-test",
        terraformCode,
        "HCL",
        {"var1": "value1"}
    )
    
    # Assertions
    assert len(workspaces) == 1
    assert workspaces[0].metadata.name == "inline-test"
    assert workspaces[0].spec.forProvider.source == "Inline"
    assert workspaces[0].spec.forProvider.module == terraformCode
    assert workspaces[0].spec.forProvider.inlineFormat == "HCL"
    assert len(workspaces[0].spec.forProvider.vars) == 1
}

# Test 3: Advanced workspace configuration
test_advanced_workspace = lambda {
    config = terraform.TerraformWorkspace {
        name = "advanced-test"
        namespace = "test-ns"
        labels = {"test": "true"}
        source = "Remote"
        module = "https://github.com/example/modules.git"
        variables = {
            "environment": "test"
            "replicas": "3"
        }
        environmentVariables = [
            terraform.TerraformEnvVar {
                name = "TF_VAR_secret"
                secretRef = terraform.ResourceReference {
                    name = "test-secret"
                    namespace = "test-ns"
                    key = "value"
                }
            }
        ]
        connectionSecret = terraform.TerraformConnectionSecret {
            name = "test-outputs"
            namespace = "test-ns"
        }
        initArgs = ["-upgrade"]
        enableTerraformCLILogging = True
    }
    
    workspaces = terraform.generateTerraformWorkspace(config)
    
    # Assertions
    assert len(workspaces) == 1
    ws = workspaces[0]
    
    assert ws.metadata.name == "advanced-test"
    assert ws.metadata.namespace == "test-ns"
    assert ws.metadata.labels.test == "true"
    
    assert ws.spec.forProvider.source == "Remote"
    assert ws.spec.forProvider.module == "https://github.com/example/modules.git"
    assert len(ws.spec.forProvider.vars) == 2
    assert len(ws.spec.forProvider.env) == 1
    assert ws.spec.forProvider.env[0].name == "TF_VAR_secret"
    assert ws.spec.forProvider.env[0].secretKeyRef.name == "test-secret"
    
    assert ws.spec.writeConnectionSecretToRef.name == "test-outputs"
    assert ws.spec.writeConnectionSecretToRef.namespace == "test-ns"
    
    assert ws.spec.forProvider.initArgs == ["-upgrade"]
    assert ws.spec.forProvider.enableTerraformCLILogging == True
}

# Test 4: Secret workspace generation
test_secret_workspace = lambda {
    workspaces = terraform.secretTerraformWorkspace(
        "secret-test",
        "https://github.com/example/secure.git",
        "db-credentials",
        "secure-ns",
        {"db_size": "small"}
    )
    
    # Assertions  
    assert len(workspaces) == 1
    ws = workspaces[0]
    
    assert ws.metadata.name == "secret-test"
    assert ws.spec.forProvider.source == "Remote"
    assert ws.spec.forProvider.module == "https://github.com/example/secure.git"
    assert ws.spec.writeConnectionSecretToRef.name == "db-credentials"
    assert ws.spec.writeConnectionSecretToRef.namespace == "secure-ns"
    assert len(ws.spec.forProvider.vars) == 1
}

# Test 5: Default values validation
test_default_values = lambda {
    config = terraform.TerraformWorkspace {
        name = "defaults-test"
        module = "https://github.com/example/test.git"
    }
    
    workspaces = terraform.generateTerraformWorkspace(config)
    ws = workspaces[0]
    
    # Check defaults
    assert ws.metadata.namespace == "default"
    assert ws.spec.forProvider.source == "Remote"
    assert ws.spec.forProvider.entrypoint == ""
    assert ws.spec.deletionPolicy == "Delete"
    assert ws.spec.managementPolicies == ["*"]
    assert ws.spec.forProvider.enableTerraformCLILogging == False
}

# Run all tests
test_git_workspace()
test_inline_workspace() 
test_advanced_workspace()
test_secret_workspace()
test_default_values()

# Test summary
print("✅ All Terraform workspace module tests passed!")