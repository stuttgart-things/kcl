# Tests for Vault Authentication Module

import ..main as vault_auth

# Test 1: Terraform code generation
test_terraform_code_generation = lambda {
    auths = [
        vault_auth.K8sAuth {
            name = "test-auth"
            namespace = "test-ns"
        }
    ]
    
    terraformCode = vault_auth.generateTerraformCode(auths)
    
    # Assertions
    assert "variable \"k8s_auths\"" in terraformCode
    assert "resource \"kubernetes_manifest\" \"service_account\"" in terraformCode
    assert "output \"service_accounts\"" in terraformCode
    assert "for_each" in terraformCode
}

# Test 2: Terraform variables conversion
test_terraform_vars_conversion = lambda {
    auths = [
        vault_auth.K8sAuth {
            name = "auth1"
            namespace = "ns1"
            automountServiceAccountToken = True
        }
        vault_auth.K8sAuth {
            name = "auth2"
            namespace = "ns2"
            automountServiceAccountToken = False
        }
    ]
    
    vars = vault_auth.authsToTerraformVars(auths)
    
    # Assertions
    assert "k8s_auths" in vars
    assert "auth1" in vars["k8s_auths"]
    assert "auth2" in vars["k8s_auths"]
    assert "ns1" in vars["k8s_auths"]
    assert "ns2" in vars["k8s_auths"]
}

# Test 3: Simple vault auth workspace
test_simple_vault_auth = lambda {
    auths = [
        vault_auth.K8sAuth {
            name = "simple-test"
            namespace = "test-namespace"
        }
    ]
    
    workspaces = vault_auth.simpleVaultAuth("test-workspace", auths)
    
    # Assertions
    assert len(workspaces) == 1
    workspace = workspaces[0]
    
    assert workspace.metadata.name == "test-workspace"
    assert workspace.spec.forProvider.source == "Inline"
    assert "kubernetes_manifest" in workspace.spec.forProvider.module
    assert len(workspace.spec.forProvider.vars) == 1
    assert workspace.spec.forProvider.vars[0].key == "k8s_auths"
}

# Test 4: Advanced vault auth with secrets
test_advanced_vault_auth = lambda {
    auths = [
        vault_auth.K8sAuth {
            name = "adv-test"
            namespace = "adv-ns"
        }
    ]
    
    workspaces = vault_auth.advancedVaultAuth(
        "advanced-test",
        "vault-system", 
        auths,
        "test-secret"
    )
    
    # Assertions
    assert len(workspaces) == 1
    workspace = workspaces[0]
    
    assert workspace.metadata.name == "advanced-test"
    assert workspace.spec.writeConnectionSecretToRef.name == "test-secret"
    assert workspace.spec.writeConnectionSecretToRef.namespace == "vault-system"
}

# Test 5: Full configuration workspace
test_full_vault_auth_config = lambda {
    config = vault_auth.VaultAuthConfig {
        workspaceName = "full-test"
        workspaceNamespace = "custom-ns"
        k8sAuths = [
            vault_auth.K8sAuth {
                name = "full-auth"
                namespace = "full-ns"
                automountServiceAccountToken = False
            }
        ]
        providerConfigRef = "custom-provider"
        connectionSecret = vault_auth.TerraformConnectionSecret {
            name = "full-secret"
            namespace = "custom-ns"
        }
        managementPolicies = ["Create", "Update"]
        deletionPolicy = "Orphan"
    }
    
    workspaces = vault_auth.generateVaultAuthWorkspace(config)
    
    # Assertions
    assert len(workspaces) == 1
    workspace = workspaces[0]
    
    assert workspace.metadata.name == "full-test"
    assert workspace.spec.forProvider.source == "Inline"
    assert workspace.spec.writeConnectionSecretToRef.name == "full-secret"
    assert workspace.spec.writeConnectionSecretToRef.namespace == "custom-ns"
}

# Test 6: Multiple ServiceAccounts
test_multiple_service_accounts = lambda {
    auths = [
        vault_auth.K8sAuth {
            name = "multi-auth-1"
            namespace = "ns1"
        }
        vault_auth.K8sAuth {
            name = "multi-auth-2"
            namespace = "ns2"
            automountServiceAccountToken = False
        }
        vault_auth.K8sAuth {
            name = "multi-auth-3"
            namespace = "ns3"
            automountServiceAccountToken = True
        }
    ]
    
    workspaces = vault_auth.simpleVaultAuth("multi-test", auths)
    workspace = workspaces[0]
    
    # Check that Terraform variables contain all auths
    terraformVars = workspace.spec.forProvider.vars[0].value
    assert "multi-auth-1" in terraformVars
    assert "multi-auth-2" in terraformVars
    assert "multi-auth-3" in terraformVars
    assert "ns1" in terraformVars
    assert "ns2" in terraformVars
    assert "ns3" in terraformVars
}

# Test 7: Default values validation
test_default_values = lambda {
    auth = vault_auth.K8sAuth {
        name = "default-test"
        namespace = "default-ns"
        # automountServiceAccountToken should default to True
    }
    
    # Verify default value
    assert auth.automountServiceAccountToken == True
    
    # Test in workspace
    workspaces = vault_auth.simpleVaultAuth("default-test", [auth])
    workspace = workspaces[0]
    
    # Default workspace namespace should be applied
    assert workspace.metadata.namespace == "default"
}

# Run all tests
test_terraform_code_generation()
test_terraform_vars_conversion()
test_simple_vault_auth()
test_advanced_vault_auth()
test_full_vault_auth_config()
test_multiple_service_accounts()
test_default_values()

# Test summary
print("✅ All Vault authentication module tests passed!")