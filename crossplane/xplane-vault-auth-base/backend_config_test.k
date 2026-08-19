# Unit tests for the kubernetes auth backend_config HCL. `kcl test`.
import .main as m

test_destroy_tolerates_a_missing_reviewer_secret = lambda {
    """The backend_config must not index the SA secret bare.

    A bare index is re-evaluated on DESTROY, and by then the reviewer Secret
    is gone -- it is a composed sibling of the same Platform XR and is deleted
    in parallel. tofu raises "Attempt to index null value", the destroy removes
    nothing, and the Workspace hangs in Deleting forever. Because its name is
    derived from clusterName+authName, a replacement XR cannot take that name
    either, so the whole teardown stalls.

    Measured on argoplatform-test1, 2026-08-19. crossplane-configurations#333.
    """
    _hcl = m._backendConfigHcl
    assert "try(data.kubernetes_secret.sa.data[var.sa_ca_cert_key], null)" in _hcl
    assert "try(data.kubernetes_secret.sa.data[var.sa_token_key], null)" in _hcl
    assert "= data.kubernetes_secret.sa.data[" not in _hcl, "bare index reintroduced"
}

test_a_missing_secret_still_fails_loudly_on_apply = lambda {
    """Destroy-tolerance must not become silent acceptance on create.

    try(..., null) alone would let tofu write an empty CA cert and an empty
    token reviewer JWT into Vault, which Vault accepts -- the auth mount would
    then exist and simply not work. The preconditions put the loud failure back
    where it belongs; they are not evaluated on destroy.
    """
    _hcl = m._backendConfigHcl
    assert "lifecycle {" in _hcl
    assert _hcl.count("precondition {") == 2
    assert "must exist before the Vault kubernetes auth backend can be configured" in _hcl
}
