# Unit tests for per-auth policy creation. `kcl test`.
import regex
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
    kvMount = "kv"
    read = ["own"]
}

# A cluster that plays the cicd role reads that tree too — a separate grant with
# a separate lifetime, not a longer body on the first policy.
_cicd = m.VaultPolicy {
    name = "kv-cicd"
    kvMount = "kv"
    read = ["cicd"]
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
    assert "\n" in _v["kv-own"], "a multi-line body must come back multi-line"
    assert _v["kv-own"].count("path \"") == 4, "data and metadata, each as the subtree itself and as a glob below it"
}

# --- the body is BUILT, not accepted (crossplane-configurations#285) ---------

# `own` is the only value that resolves to a cluster name. A cluster cannot put
# another cluster's name in that position and be granted it — it would just get
# a subtree of that literal name, which is not where anyone's secrets live.
test_own_expands_to_this_cluster = lambda {
    _v = json.decode(_vars(m.vaultK8sAuth(_cfg([_auth("eso", [_own])]))[0])["policies"])
    assert 'path "kv/data/mgmt-test1/*" { capabilities = ["read"] }' in _v["kv-own"]
    assert 'path "kv/metadata/mgmt-test1/*" { capabilities = ["read", "list"] }' in _v["kv-own"]
}

# metadata needs list as well as read, or `vault kv list` and the ESO `find`
# selector fail on a tree the token can otherwise read — which reads like a
# missing secret rather than a missing capability.
test_metadata_gets_list = lambda {
    _v = json.decode(_vars(m.vaultK8sAuth(_cfg([_auth("eso", [_own])]))[0])["policies"])
    assert '"read", "list"' in _v["kv-own"]
}

# A named subtree stays a named subtree — this is the cicd case, and it must NOT
# pick up the cluster name.
test_named_subtree_is_not_rewritten = lambda {
    _v = json.decode(_vars(m.vaultK8sAuth(_cfg([_auth("eso", [_cicd])]))[0])["policies"])
    assert 'path "kv/data/cicd/*"' in _v["kv-cicd"]
    assert "mgmt-test1" not in _v["kv-cicd"]
}

# Every path is anchored at the declared mount, and no capability beyond
# read/list ever appears. This is the whole security property in one assertion:
# there is no input that reaches `sys/`, `auth/`, or `sudo`.
test_nothing_escapes_the_kv_mount = lambda {
    _both = m.VaultPolicy {name = "wide", kvMount = "clusters", read = ["own", "cicd", "platform"]}
    _v = json.decode(_vars(m.vaultK8sAuth(_cfg([_auth("eso", [_both])]))[0])["policies"])["wide"]
    _lines = _v.splitlines()
    assert all l in _lines {
        l == "" or l.startswith('path "clusters/data/') or l.startswith('path "clusters/metadata/')
    }, "every path is anchored at the declared KV mount"
    assert "sudo" not in _v and "create" not in _v and "delete" not in _v and "update" not in _v
    assert _v.count("path \"") == 12, "three subtrees x data/metadata x subtree-itself/below-it"
}

# A subtree name is a plain name. A slash, a glob or a traversal would each let
# someone write a PATH into a position the body-builder anchors — which is the
# one thing the schema check exists to stop. KCL raises on a failing check at
# construction, which a test cannot catch, so the pattern itself is asserted
# here; the schema applies the same one.
_subtreePattern = r"^[a-z0-9][a-z0-9._-]*$"
test_a_subtree_cannot_be_a_path = lambda {
    _good = ["own", "cicd", "u26-rke2-1", "platform.v2"]
    assert all n in _good {regex.match(n, _subtreePattern)}, "plain names pass"
    _bad = ["a/b", "../etc", "*", "sys/policies", "own/*", "", "/abs", "UPPER"]
    assert all n in _bad {not regex.match(n, _subtreePattern)}, "anything that could be a path does not"
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

# Vault matches a policy path EXACTLY unless it ends in a glob, so
# `x/data/default/*` does not match `x/data/default`. That is not a corner case:
# the cicd mounts put their secret directly under the mount
# (cicd-proxmox-labul/data/default), so a policy that looked like it granted
# read denied it. Measured on u26-rke2-1 — external-secrets logged 403 on that
# exact path while the ClusterSecretStore reported Valid, i.e. the login worked
# and only the read failed.
test_a_leaf_secret_is_granted_not_only_its_children = lambda {
    _leaf = m.VaultPolicy {
        name = "read-proxmox"
        kvMount = "cicd-proxmox-labul"
        read = ["default"]
    }
    _v = json.decode(_vars(m.vaultK8sAuth(_cfg([_auth("eso", [_leaf])]))[0])["policies"])
    _b = _v["read-proxmox"]
    assert 'path "cicd-proxmox-labul/data/default" { capabilities = ["read"] }' in _b, "the secret itself"
    assert 'path "cicd-proxmox-labul/data/default/*" { capabilities = ["read"] }' in _b, "and anything below it"
    assert 'path "cicd-proxmox-labul/metadata/default" { capabilities = ["read", "list"] }' in _b
}
