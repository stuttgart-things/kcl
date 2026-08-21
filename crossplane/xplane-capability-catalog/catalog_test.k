import .main as c

test_every_entry_is_registered_under_its_own_name = lambda {
    _wrong = [n for n in c.names if c.catalog[n].name != n]
    assert _wrong == [], "catalog key and Capability.name disagree: " + str(_wrong)
}

test_get_rejects_an_unknown_name = lambda {
    assert len(c.names) == 3
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

# The entry that made the schema earn its keep. `ansibleExtraCollections` reaches
# Tekton as a parameter, and a stringified list is rejected there with
# ParameterTypeMismatch — an error naming the Tekton parameter and nothing about
# where the value came from. So placement values are not all strings, and the
# renderer must not coerce them.
test_list_valued_defaults_stay_lists = lambda {
    _v = c.get("ansible-run").defaults["ansibleExtraCollections"]
    assert typeof(_v) == "list", "a stringified list is a ParameterTypeMismatch in Tekton"
    assert len(_v) > 0
}

# ansible-run configures a Configuration, not a provider — so it has no
# ClusterProviderConfig, and the renderer must emit none rather than an empty
# one. providerConfig was optional from the first version for this case.
test_ansible_run_has_no_provider_config = lambda {
    assert not c.get("ansible-run")?.providerConfig
    assert c.get("proxmoxvm")?.providerConfig, "while a provider capability does"
}

# Two plain keys, because the consumer is a pipeline reading environment
# variables — not a Terraform provider parsing one credentials document. The
# single-key rule is asserted only for capabilities WITH a provider config, and
# this is the entry that would break a rule stated too broadly.
test_pipeline_credentials_are_plain_keys = lambda {
    _d = c.get("ansible-run").credentials.data
    assert len(_d) == 2
    assert "ANSIBLE_USER" in _d and "ANSIBLE_PASSWORD" in _d
}

# The name and the namespace of a credentials Secret are DERIVED, and both are
# silent when wrong: an EnvironmentConfig naming a Secret that does not exist
# makes the consumer report a missing credential rather than a wrong name, and
# a Secret beside the provider is simply never read by a pipeline running
# elsewhere.
test_derived_credential_fields_are_not_also_defaulted = lambda {
    _bad = [n for n in c.names if c.get(n)?.credentialsNameField and c.get(n).credentialsNameField in c.get(n).defaults]
    assert _bad == [], "a derived field must not have a default that diverges from it: " + str(_bad)
}

# ansible's credentials are read by a Tekton pipeline in the pipeline's own
# namespace — the same trap as a cloud-init password beside the provider.
test_ansible_run_credentials_live_where_the_pipeline_runs = lambda {
    _a = c.get("ansible-run")
    assert _a.credentialsNamespaceField == "namespace"
    assert _a.credentialsNamespaceField in _a.required, "and that namespace must be stated, not guessed"
}

# The label a consumer selects on is derived from the entry name, and
# function-environment-configs requires EXACTLY ONE match — so a name that does
# not match its consumer's label produces zero matches and an error naming the
# selector rather than the entry. These are the labels the Compositions in
# crossplane-configurations actually select on; check there before adding one.
test_entry_names_match_their_consumers_selectors = lambda {
    _consumers = {
        "ansible-run" = "ansible-run.resources.stuttgart-things.com/environment"
        "proxmoxvm" = "proxmoxvm.resources.stuttgart-things.com/environment"
        "vspherevm" = "vspherevm.resources.stuttgart-things.com/environment"
    }
    _wrong = [n for n in _consumers if c.get(n).environmentLabelKey != _consumers[n]]
    assert _wrong == [], "these emit a label their Composition does not select: " + str(_wrong)
    assert sorted([n for n in _consumers]) == c.names, "a new entry needs its consumer's selector checked here"
}

# Die proxmoxvm-Composition loest ihren cloud-init-Datastore als
# spec.cloudInit.datastoreId -> EnvironmentConfig `cloudInitDatastore` ->
# Datastore der Rootplatte auf. Kennt der Katalog den Schluessel nicht, kann die
# von der Capability erzeugte EnvironmentConfig ihn nicht tragen und jede so
# gebaute VM faellt auf das letzte Glied der Kette durch — auf LabUL ist das der
# Storage, auf dem der cidata-Umlauf kaputt ist und die VM beim ersten
# Stop/Start unbootbar wird. Bis 0.5.0 war das der Fall, ohne Fehler und ohne
# Hinweis im Status.
#
# Nagelt nur die Existenz fest, nicht den Wert: ein Storage-Name ist eine
# Standort-Wahrheit und gehoert ins XR, nicht in den Katalog.
test_proxmox_can_place_the_cloudinit_drive = lambda {
    assert "cloudInitDatastore" in c.fields("proxmoxvm"), "die Composition liest den Schluessel; ohne Katalogeintrag wird er stillschweigend verworfen"
    assert "cloudInitDatastore" not in c.get("proxmoxvm").defaults, "kein Default: DD-sthings gilt fuer LabUL, nicht fuer jeden Proxmox-Cluster"
}
