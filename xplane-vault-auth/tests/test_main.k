import main as vault_auth
import regex

# Test basic functionality
testAuth = vault_auth.K8sAuth {
    name = "test-app"
    clusterName = "test-cluster"
    vaultAddr = "https://vault.test.com"
}

# Generate Terraform workspace
workspace = vault_auth.vaultK8sAuth(testAuth)[0]

# Test assertions
assert workspace.apiVersion == "tf.upbound.io/v1beta1"
assert workspace.kind == "Workspace"
assert workspace.metadata.name == "test-app-vault-k8s-auth"
assert workspace.spec.forProvider.source == "Inline"# Test Terraform code generation
terraformCode = vault_auth.generateServiceAccountTerraform(testAuth)
assert "kubernetes_service_account" in terraformCode
assert "kubernetes_cluster_role_binding" in terraformCode
assert "kubernetes_secret" in terraformCode
assert "test-app-vault-auth" in terraformCode

# Test simple authentication function
simpleWorkspace = vault_auth.simpleVaultK8sAuth("simple-test", "cluster", "https://vault.com")[0]
assert simpleWorkspace.metadata.name == "simple-test-vault-k8s-auth"

print("All tests passed! ✓")