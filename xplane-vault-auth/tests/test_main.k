import main as vault_auth

# Test simple authentication backend
simpleAuth = vault_auth.simpleVaultK8sAuth("test-app", "test-cluster", "https://vault.test.com")

# Test assertions for simple auth (returns list with one workspace)
assert len(simpleAuth) == 1
workspace = simpleAuth[0]
assert workspace.apiVersion == "tf.upbound.io/v1beta1"
assert workspace.kind == "Workspace"
assert workspace.metadata.name == "test-cluster-test-app-vault-auth"
assert workspace.spec.forProvider.source == "Inline"
assert "vault_auth_backend" in workspace.spec.forProvider.module
assert "provider \"vault\"" in workspace.spec.forProvider.module

# Test auth with policies
authWithPolicies = vault_auth.simpleVaultK8sAuthWithPolicies(
    "cicd-app",
    "prod-cluster",
    "https://vault.prod.com",
    ["read-policy", "write-policy"]
)

assert len(authWithPolicies) == 1
policyWorkspace = authWithPolicies[0]
assert policyWorkspace.metadata.name == "prod-cluster-cicd-app-vault-auth"
assert "token_policies                   = var.token_policies" in policyWorkspace.spec.forProvider.module
assert "token_ttl                        = var.token_ttl" in policyWorkspace.spec.forProvider.module

# Validate variables in workspace
vars = policyWorkspace.spec.forProvider.vars
tokenPoliciesVar = [v for v in vars if v.key == "token_policies"][0]
assert tokenPoliciesVar.value == "[read-policy, write-policy]"# Test advanced auth configuration
advancedAuth = vault_auth.advancedVaultK8sAuth(
    "advanced-app",
    "staging",
    "https://vault.staging.com",
    ["advanced-policy"],
    1800
)

assert len(advancedAuth) == 1
advancedWorkspace = advancedAuth[0]
assert advancedWorkspace.metadata.name == "staging-advanced-app-vault-auth"

# Test single workspace creation directly
directAuth = vault_auth.K8sAuth {
    name = "direct-app"
    clusterName = "direct-cluster"
    vaultAddr = "https://vault.direct.com"
}
singleAuth = vault_auth.createSingleVaultAuth(directAuth)
assert len(singleAuth) == 1
assert singleAuth[0].metadata.name == "direct-cluster-direct-app-vault-auth"

print("All tests passed! ✓")
