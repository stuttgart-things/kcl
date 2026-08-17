# Unit tests for the decisions. `kcl test` — no Crossplane, no cluster.
import .logic
import xplane_capability_catalog.main as cat

_full = {
    node = "ul-pve01"
    datastore = "V5010-01-1"
    bridge = "vmbrvlan"
    vlanTag = "102"
    pool = "stuttgart-things"
    templateVmId = "211"
}

test_a_complete_placement_has_no_problems = lambda {
    assert logic.missingRequired("proxmoxvm", _full) == []
    assert logic.unknownFields("proxmoxvm", _full) == []
    assert logic.problems(["proxmoxvm"], {proxmoxvm = _full}) == []
}

# The point of failing the render: a missing node does not surface as a
# validation error, it surfaces minutes later as a VM the provider tries to
# place nowhere, in a message that names the provider and not this XR.
test_a_missing_required_field_is_named = lambda {
    _p = logic.problems(["proxmoxvm"], {proxmoxvm = {n: _full[n] for n in _full if n != "node"}})
    assert len(_p) == 1
    assert "node" in _p[0]
    assert "proxmoxvm" in _p[0]
}

# An XRD default or a half-filled values file arrives as "" rather than as an
# absent key, and "" is exactly as unusable as absent for a node name.
test_an_empty_string_counts_as_missing = lambda {
    assert logic.missingRequired("proxmoxvm", _full | {node = ""}) == ["node"]
}

# Without this a typo lands nowhere: the key is dropped from the emitted
# EnvironmentConfig, the required field it was meant to be stays missing, and
# the error names the field the user did NOT write.
test_a_typo_is_rejected_rather_than_dropped = lambda {
    assert logic.unknownFields("proxmoxvm", _full | {templateVMID = "211"}) == ["templateVMID"]
    _p = logic.problems(["proxmoxvm"], {proxmoxvm = _full | {templateVMID = "211"}})
    assert len(_p) == 1 and "templateVMID" in _p[0]
}

# Catalog defaults must not be re-stated on the XR to take effect, and an XR
# value must win when it is stated.
test_defaults_apply_and_the_xr_wins = lambda {
    _r = logic.placement("proxmoxvm", _full)
    assert _r.diskInterface == "virtio0", "sthings-u26 boots off virtio0"
    assert logic.placement("proxmoxvm", _full | {diskInterface = "scsi0"}).diskInterface == "scsi0"
}

# EnvironmentConfig data is string-typed. A YAML author writing `vlanTag: 102`
# would otherwise produce an int and the apply fails on type, not on content.
test_numbers_are_stringified = lambda {
    assert logic.placement("proxmoxvm", _full | {vlanTag = 102}).vlanTag == "102"
}

# All capabilities are reported at once. A render is all-or-nothing, so fixing
# one field per reconcile is the difference between one round-trip and six.
test_every_capability_is_reported_in_one_pass = lambda {
    _p = logic.problems(["proxmoxvm", "vspherevm"], {proxmoxvm = {}, vspherevm = {}})
    assert len(_p) == 2
}

# cloneDatastore is optional for a reason worth keeping visible: bpg's clone
# block is ForceNew, so a value appearing here rewrites the clone block of every
# VM already built under this EnvironmentConfig — destroy and recreate,
# unattended.
test_optional_fields_are_accepted_but_not_defaulted = lambda {
    assert "cloneDatastore" not in logic.placement("proxmoxvm", _full)
    assert logic.placement("proxmoxvm", _full | {cloneDatastore = "V5010-01-1"}).cloneDatastore == "V5010-01-1"
    assert "cloneDatastore" in cat.fields("proxmoxvm")
}

# A capability that names its own KV mount needs a Vault server. The failure is
# worth naming precisely because it is not "you forgot a field" — everything
# else about the store is derived, so this is the one fact left.
test_a_store_without_a_server_is_rejected = lambda {
    assert logic.validateStores(["proxmoxvm"], {
        proxmoxvm = {mount = "cicd-proxmox-labul"}
    }, "https://vault.example.com", "c-eso")
    assert logic.validateStores(["proxmoxvm"], {
        proxmoxvm = {mount = "cicd-proxmox-labul", server = "https://per-cap.example.com"}
    }, "", "c-eso")
}

# Naming an existing store means "use that one" — nothing is created, so no
# server is needed. This is how a cluster keeps a store it already trusts.
test_an_existing_store_needs_no_vault_facts = lambda {
    assert logic.validateStores(["proxmoxvm"], {
        proxmoxvm = {secretStoreName = "vault-cluster-secrets"}
    }, "", "")
}

# Nothing enabled, nothing to validate. Guarded for the same reason validate()
# is: the module is compiled during `kcl test` with no request at all.
test_no_capabilities_means_no_store_requirements = lambda {
    assert logic.validateStores([], {}, "", "")
}

# Readiness is not one setting for all four objects, and both directions are
# failures that hide.
#
# provider-kubernetes derives readiness from the managed object's own
# conditions. An EnvironmentConfig and a ClusterProviderConfig have none, so
# DeriveFromObject leaves them at Ready=False forever while what they created is
# present and correct — found on u26-rke2-1 on the first apply, and measured for
# ClusterProviderConfig in crossplane-configurations#294.
test_status_less_objects_do_not_derive_readiness_from_themselves = lambda {
    _statusLess = ["EnvironmentConfig", "ClusterProviderConfig"]
    _wrong = [k for k in _statusLess if logic.readinessFor(k).policy == "DeriveFromObject"]
    assert _wrong == [], "these have no conditions to derive from: " + str(_wrong)
}

# The other direction. An ExternalSecret DOES report Ready, and that condition is
# the only signal that Vault actually answered — a constant would make a
# capability whose credentials 403 report ready.
test_secret_objects_derive_readiness_from_themselves = lambda {
    _wrong = [k for k in ["ExternalSecret", "ClusterSecretStore"] if logic.readinessFor(k).policy != "DeriveFromObject"]
    assert _wrong == [], "these carry the only evidence that Vault answered: " + str(_wrong)
}

# The XRD declares status.capabilities.<n>.secretStore, and for one release the
# module did not write it — an edit lost to a reformat. #283 is the same drift
# in the other direction (module writes, XRD does not declare), where every
# compose fails; this direction breaks nothing and is therefore worse to spot:
# the field is documented and simply never appears. Both need the two sides
# named in one place.
statusFields = ["ready", "environmentConfig", "credentialsSecret", "secretStore", "providerConfig"]

test_status_fields_are_the_ones_the_xrd_declares = lambda {
    _want = ["credentialsSecret", "environmentConfig", "providerConfig", "ready", "secretStore"]
    assert sorted(statusFields) == _want, "keep this in step with the XRD in crossplane-configurations/bootstrap/capability"
}
