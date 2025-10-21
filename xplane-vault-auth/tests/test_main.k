import main as vault_auth

# Test basic functionality
testConfig = vault_auth.VaultConfig {
    k8sAuths = [vault_auth.K8sAuth {
        name = "test-app"
        clusterName = "test-cluster"
        vaultAddr = "https://vault.test.com"
    }]
    clusterName = "test-cluster"
    vaultAddr = "https://vault.test.com"
}

# Generate Terraform workspace
workspace = vault_auth.vaultK8sAuth(testConfig)[0]

# Test assertions  
assert workspace.apiVersion == "tf.upbound.io/v1beta1"
assert workspace.kind == "Workspace"
assert workspace.metadata.name == "test-cluster-vault-k8s-auth"
assert workspace.spec.forProvider.source == "Inline"

# Test Terraform code generation
terraformCode = vault_auth.generateVaultAuthTerraform(testConfig)
assert "vault_auth_backend" in terraformCode
assert "provider \"vault\"" in terraformCode
assert "for_each" in terraformCode

# Test simple authentication function
simpleWorkspace = vault_auth.simpleVaultK8sAuth("simple-test", "cluster", "https://vault.com")[0]
assert simpleWorkspace.metadata.name == "cluster-vault-k8s-auth"

# Test multi auth function
multiWorkspace = vault_auth.multiVaultK8sAuth([
    vault_auth.K8sAuth {
        name = "app1"
        clusterName = "test"
        vaultAddr = "https://vault.test.com"
    }
    vault_auth.K8sAuth {
        name = "app2"
        clusterName = "test"
        vaultAddr = "https://vault.test.com"
    }
], "test", "https://vault.test.com")[0]
assert multiWorkspace.metadata.name == "test-vault-k8s-auth"

print("All tests passed! ✓")
