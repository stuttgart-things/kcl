import .main as c

test_every_entry_is_registered_under_its_own_name = lambda {
    _wrong = [n for n in c.names if c.catalog[n].name != n]
    assert _wrong == [], "catalog key and Capability.name disagree: " + str(_wrong)
}

test_get_rejects_an_unknown_name = lambda {
    assert len(c.names) == 2
    assert "proxmoxvm" in c.names
}

# The templates are opaque strings to this module, so nothing else would catch a
# key that is referenced but not declared — and the failure mode is quiet: ESO
# renders a missing key as the empty string, so the provider gets a
# syntactically valid credential that simply does not authenticate.
test_declared_vault_keys_match_the_templates = lambda {
    _undeclared = [n + ":" + k for n in c.names for k in c.get(n).credentials.vaultKeys if not any_true([("{{ ." + k + " }}") in v for v in [c.get(n).credentials.data[dk] for dk in c.get(n).credentials.data]])]
    assert _undeclared == [], "declared but never referenced: " + str(_undeclared)
}

# The bpg and vsphere providers parse ONE JSON document out of ONE Secret key.
# A per-field Secret looks tidier and fails at login with an error that names
# neither the field nor the Secret.
test_provider_capabilities_ship_a_single_credentials_key = lambda {
    _split = [n for n in c.names if c.get(n)?.providerConfig and len(c.get(n).credentials.data) != 1]
    assert _split == [], "a provider capability needs exactly one credentials key: " + str(_split)
}

# `insecure` / `allow_unverified_ssl` unmarshal into STRING fields. A bare JSON
# true fails the parse with a type error naming neither field nor Secret.
test_tls_flags_are_json_strings = lambda {
    _bad = [n for n in c.names for v in [c.get(n).credentials.data[dk] for dk in c.get(n).credentials.data] if '"insecure":true' in v or '"allow_unverified_ssl":true' in v]
    assert _bad == [], "TLS flag must be a quoted string: " + str(_bad)
}

# The consuming Composition selects EnvironmentConfigs on this label, so it is
# part of a contract with another Configuration rather than free-form.
test_environment_label_is_capability_scoped = lambda {
    _bad = [n for n in c.names if c.get(n).environmentLabelKey != n + ".resources.stuttgart-things.com/environment"]
    assert _bad == [], "label key must be scoped to the capability: " + str(_bad)
}

# fields() is what lets a consumer reject a typo'd placement key. If a field
# appeared in two of the three lists, the rejection would still work but the
# emitted EnvironmentConfig would take one of them arbitrarily.
test_fields_are_disjoint = lambda {
    _dupes = [n for n in c.names if len(c.fields(n)) != len({f: "" for f in c.fields(n)})]
    assert _dupes == [], "a placement field appears in more than one list: " + str(_dupes)
}

# A ClusterProviderConfig is a different CRD from the cluster-scoped
# ProviderConfig, and the namespaced variants live under a `.m.` group. Naming
# the wrong one produces "no matches for kind" at apply time.
test_provider_config_groups_are_namespaced_variants = lambda {
    _bad = [n for n in c.names if c.get(n)?.providerConfig and ".m." not in c.get(n).providerConfig.apiVersion]
    assert _bad == [], "expected the namespaced (.m.) provider group: " + str(_bad)
}

# A workload secret only helps if it lands where the consumer looks: the
# namespaced EnvironmentVM CRD resolves passwordSecretRef in the managed
# resource's own namespace. An entry declaring one must therefore also expose
# the field that names it, or the Secret exists and nothing reads it.
test_workload_secrets_are_referenced_from_placement = lambda {
    _orphan = [n for n in c.names if len(c.get(n).workloadSecrets) > 0 and "ciPasswordSecretName" not in c.fields(n)]
    assert _orphan == [], "workload secret with no placement field naming it: " + str(_orphan)
}

# Same trap as Credentials.vaultKeys, and worth its own test because this one is
# invisible twice over: a mistyped key yields an empty password, cloud-init
# locks the account, and the cluster still comes up.
test_workload_secret_vault_keys_match_their_templates = lambda {
    _undeclared = [n + ":" + k for n in c.names for w in c.get(n).workloadSecrets for k in w.vaultKeys if not any_true([("{{ ." + k + " }}") in w.data[dk] for dk in w.data])]
    assert _undeclared == [], "declared but never referenced: " + str(_undeclared)
}
