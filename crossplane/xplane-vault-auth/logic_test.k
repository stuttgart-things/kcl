# Unit tests for the status shaping. `kcl test`.
import .logic as l

_ws = lambda ready: bool, outputs: {str:} -> any {
    {
        metadata = {name = "mgmt-test1-eso-vault-auth"}
        status = {
            conditions = [{type = "Ready", status = "True" if ready else "False"}]
            atProvider = {outputs = outputs}
        }
    }
}

_full = {
    auth_backend_path = "mgmt-test1-eso"
    auth_role_name = "eso"
    policy_names = ["mgmt-test1-kv-own", "mgmt-test1-kv-cicd"]
}

# Derived on both sides so the two cannot drift: the base module names the
# Workspace the same way.
test_workspace_name_is_derived = lambda {
    assert l.workspaceName("mgmt-test1", "eso") == "mgmt-test1-eso-vault-auth"
}

test_outputs_are_lifted = lambda {
    _a = l.authStatus("mgmt-test1", "eso", _ws(True, _full))
    assert _a.ready
    assert _a.mountPath == "mgmt-test1-eso"
    assert _a.role == "eso"
    assert _a.policies == ["mgmt-test1-kv-own", "mgmt-test1-kv-cicd"]
    assert _a.workspace == "mgmt-test1-eso-vault-auth"
}

# THE rule. While the Workspace is still applying there are no outputs, and the
# fields must be ABSENT rather than empty: a consumer resolving a substitution
# source to "" would send a blank mount path to Vault, which answers with a 403
# that names nothing. The value looks supplied and is not.
test_missing_outputs_are_omitted_not_blank = lambda {
    _a = l.authStatus("mgmt-test1", "eso", _ws(False, {}))
    assert not _a.ready
    assert "mountPath" not in _a, "absent is a state a consumer can act on; empty is not"
    assert "role" not in _a
    assert "policies" not in _a
    assert _a.name == "eso", "identity is known before the Workspace produces anything"
}

# A Workspace that has not been observed at all — first reconcile, ocds empty.
test_unobserved_workspace_yields_identity_only = lambda {
    _a = l.authStatus("mgmt-test1", "eso", {})
    assert not _a.ready
    assert "mountPath" not in _a
}

# Partial outputs happen: tofu can publish one before the other.
test_partial_outputs_are_partial = lambda {
    _a = l.authStatus("mgmt-test1", "eso", _ws(False, {auth_backend_path = "mgmt-test1-eso"}))
    assert _a.mountPath == "mgmt-test1-eso"
    assert "role" not in _a
}

# Aggregate readiness. False on empty deliberately: a VaultK8sAuth with no auths
# has created nothing, and reporting it ready would let a consumer proceed
# against a Vault that knows nothing about this cluster.
test_all_ready_needs_every_auth = lambda {
    _r = {name = "a", ready = True}
    _n = {name = "b", ready = False}
    assert l.allReady([_r])
    assert l.allReady([_r, _r])
    assert not l.allReady([_r, _n])
    assert not l.allReady([]), "nothing created is not the same as everything ready"
}
