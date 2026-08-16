# Unit tests for per-auth policy creation. `kcl test`.
import .main as m

_auth = lambda name: str, policies: [m.VaultPolicy] -> m.K8sAuth {
    m.K8sAuth {
        name = name
        clusterName = "mgmt-test1"
        vaultAddr = "https://vault.example"
        tokenPolicies = ["read-secrets"]
        policies = policies
    }
}

_own = m.VaultPolicy {
    name = "kv-own"
    rules = "path \"kv/data/mgmt-test1/*\" { capabilities = [\"read\"] }"
}

# A cluster that plays the cicd role reads that tree too — a separate grant with
# a separate lifetime, not a longer body on the first policy.
_cicd = m.VaultPolicy {
    name = "kv-cicd"
    rules = "path \"kv/data/cicd/*\" { capabilities = [\"read\"] }"
}

_cfg = lambda auths: [m.K8sAuth] -> m.VaultConfig {
    m.VaultConfig {
        k8sAuths = auths
        clusterName = "mgmt-test1"
        vaultAddr = "https://vault.example"
        namespace = "default"
        vaultTokenSecret = "vault-approle"
        vaultTokenSecretKey = "terraform.tfvars"
        providerConfigName = "in-cluster"
        providerConfigKind = "ClusterProviderConfig"
    }
}

_vars = lambda w -> {str:str} {
    {v.key: v.value for v in w.spec.forProvider.vars}
}

# Declared policies reach the workspace as a JSON map. Without any, the map is
# empty, for_each iterates nothing and the plan is what it was — a caller that
# only references existing policies is unaffected.
test_policies_reach_the_workspace = lambda {
    _ws = m.vaultK8sAuth(_cfg([_auth("eso", [_own, _cicd]), _auth("certmanager", [])]))
    _with = json.decode(_vars(_ws[0])["policies"])
    assert sorted(_with) == ["kv-cicd", "kv-own"], "both grants travel"
    assert "kv/data/cicd/" in _with["kv-cicd"]
    assert _vars(_ws[1])["policies"] == "{}", "no policies means no vault_policy resources"
}

# More than one is the normal case, not an edge: a cluster reads its own subtree
# AND whatever the role it plays grants it. Two policies, two lifetimes.
test_several_policies_per_auth = lambda {
    _v = json.decode(_vars(m.vaultK8sAuth(_cfg([_auth("eso", [_own, _cicd])]))[0])["policies"])
    assert len(_v) == 2
}

# The bodies carry quotes and newlines, so they are JSON-encoded rather than
# assembled by string concatenation the way the name lists are.
test_policy_bodies_survive_encoding = lambda {
    _v = json.decode(_vars(m.vaultK8sAuth(_cfg([_auth("eso", [_own])]))[0])["policies"])
    assert _v["kv-own"] == _own.rules, "quotes must come back exactly as written"
}

# THE point of doing this in one plan. Vault accepts a role naming a policy that
# does not exist — the token then has no permissions, with no error anywhere.
# The role must therefore reference the policy resource, so tofu orders them and
# a destroy reverses the order.
test_the_role_references_the_policy_resource = lambda {
    _mod = m.vaultK8sAuth(_cfg([_auth("eso", [_own])]))[0].spec.forProvider.module
    assert "resource \"vault_policy\" \"auth\"" in _mod
    assert "[for p in vault_policy.auth : p.name]" in _mod, "the role must depend on the policy, not merely coexist"
    assert "concat(var.token_policies" in _mod, "created policy is appended, never replaces"
}

# The name is derived, not passed: a caller who had to repeat it could misspell
# it, and Vault would accept the result silently.
test_policy_name_is_derived = lambda {
    _mod = m.vaultK8sAuth(_cfg([_auth("eso", [_own])]))[0].spec.forProvider.module
    assert r'name     = "${var.cluster_name}-${each.key}"' in _mod
    assert "output \"policy_names\"" in _mod
}

# tokenPolicies stays untouched — the created policy is added at apply time by
# concat, so an XR never sees a list it did not write.
test_token_policies_are_not_rewritten = lambda {
    _v = _vars(m.vaultK8sAuth(_cfg([_auth("eso", [_own])]))[0])
    assert _v["token_policies"] == "[\"read-secrets\"]"
}
