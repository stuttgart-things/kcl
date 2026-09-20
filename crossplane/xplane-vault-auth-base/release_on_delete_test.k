# Unit tests for releaseOnDelete — handing Vault objects to another owner
# instead of destroying them (crossplane-configurations#482). `kcl test`.
import .main as m

# NOTE: every file in this package shares one scope, so the helpers here carry a
# prefix — policy_test.k already has _auth and _cfg.
_rodAuth = m.K8sAuth {
    name = "certmanager"
    clusterName = "homerun2-test1"
    vaultAddr = "https://vault.example"
}

_rodCfg = lambda release: bool -> m.VaultConfig {
    m.VaultConfig {
        k8sAuths = [_rodAuth]
        clusterName = "homerun2-test1"
        vaultAddr = "https://vault.example"
        releaseOnDelete = release
    }
}

# The default is unchanged behaviour: a delete destroys, as it always did. Any
# other default would silently orphan Vault objects for every existing caller.
test_default_still_destroys = lambda {
    _rodWs = m.vaultK8sAuth(_rodCfg(False))[0]
    assert _rodWs.spec.managementPolicies == ["*"]
}

# Everything except Delete: the Workspace keeps reconciling and correcting the
# mount right up until it is removed, and only the destroy is withheld.
test_release_drops_only_delete = lambda {
    _rodWs = m.vaultK8sAuth(_rodCfg(True))[0]
    assert "Delete" not in _rodWs.spec.managementPolicies
    assert "Observe" in _rodWs.spec.managementPolicies
    assert "Create" in _rodWs.spec.managementPolicies
    assert "Update" in _rodWs.spec.managementPolicies
}

# Stated even when false. A defaulted field belongs to whoever created the
# object, and Crossplane drops it when the desired state stops mentioning it —
# so the value has to come from the composition in both directions.
test_always_stated = lambda {
    assert m.vaultK8sAuth(_rodCfg(False))[0].spec.managementPolicies != Undefined
    assert m.vaultK8sAuth(_rodCfg(True))[0].spec.managementPolicies != Undefined
}

# The flag is config-wide: a cluster hands over all of its auths at once, never
# cert-manager without external-secrets.
test_applies_to_every_auth = lambda {
    _rodMulti = m.VaultConfig {
        k8sAuths = [_rodAuth, m.K8sAuth {
            name = "eso"
            clusterName = "homerun2-test1"
            vaultAddr = "https://vault.example"
        }]
        clusterName = "homerun2-test1"
        vaultAddr = "https://vault.example"
        releaseOnDelete = True
    }
    _rodPolicies = [ws.spec.managementPolicies for ws in m.vaultK8sAuth(_rodMulti)]
    assert len(_rodPolicies) == 2
    assert len([p for p in _rodPolicies if "Delete" in p]) == 0
}
