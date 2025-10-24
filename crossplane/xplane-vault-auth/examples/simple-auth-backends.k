import ..main as vault_auth

# Example 1: Simple auth backend (no policies)
devAuth = vault_auth.simpleVaultK8sAuth(
    "dev-backend",
    "my-cluster",
    "https://vault.example.com"
)

# Example 2: Auth backend with policies
cicdAuth = vault_auth.simpleVaultK8sAuthWithPolicies(
    "cicd-backend",
    "my-cluster",
    "https://vault.example.com",
    ["read-secrets", "write-secrets"]
)# Example 3: Advanced auth with custom TTL
prodAuth = vault_auth.advancedVaultK8sAuth(
    "prod-backend",
    "prod-cluster",
    "https://vault.prod.com",
    ["prod-read", "prod-write"],
    7200  # 2 hours
)

# Example 4: Multiple separate auth backends
# Each creates its own Crossplane Workspace
multipleAuths = [
    vault_auth.K8sAuth {
        name = "app1"
        clusterName = "staging"
        vaultAddr = "https://vault.staging.com"
        tokenPolicies = ["app1-policy"]
        tokenTtl = 1800
    }
    vault_auth.K8sAuth {
        name = "app2"
        clusterName = "staging"
        vaultAddr = "https://vault.staging.com"
        tokenPolicies = ["app2-policy"]
        tokenTtl = 3600
    }
]

stagingAuths = vault_auth.multiVaultK8sAuth(multipleAuths, "staging", "https://vault.staging.com")

# Output individual auth backends
dev = devAuth
cicd = cicdAuth
prod = prodAuth
staging_app1 = stagingAuths[0]
staging_app2 = stagingAuths[1]
