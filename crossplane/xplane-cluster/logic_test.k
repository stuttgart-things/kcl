# Unit tests for the resource construction. Run with `kcl test`.
# These import logic.k, not main.k — main.k reads option("params") and is
# exercised by the Configuration's `crossplane render`, not here.
import .logic as l
import xplane_cluster_catalog as cat

# Specs are written out in full rather than merged from a base: KCL types a dict
# literal by its keys, so `base | {clusterName = ...}` fails type checking on the
# key the base does not have. Verbose, but explicit is fine in tests.

# --- inventory -------------------------------------------------------------
# The first group gets the host, the rest are present-but-empty. Not cosmetic:
# deploy_configure_rke branches on groups['initial_master_node'] and
# groups['additional_master_nodes'], so a flat inventory fails with an
# undefined-group error, and an omitted empty group fails the same way.
test_inventory_puts_the_host_in_the_first_group_only = lambda {
    _inv = l.renderInventory(["initial_master_node", "additional_master_nodes", "workers"], "10.0.0.1")
    assert _inv == [
        'initial_master_node+["10.0.0.1"]'
        "additional_master_nodes+[]"
        "workers+[]"
    ]
}

test_single_group_inventory = lambda {
    assert l.renderInventory(["all"], "10.0.0.1") == ['all+["10.0.0.1"]']
}

test_vars_render_to_the_ansible_run_syntax = lambda {
    assert l.renderVars({a = "1"}) == ["a+-1"]
}

# --- provider field names --------------------------------------------------
# The ONLY thing that differs between providers. If this ever grows a second
# difference, the "provider is a one-word switch" claim in the README is wrong.
test_proxmox_uses_memory_vsphere_uses_ram = lambda {
    _size = cat.getSize("medium")
    _px = l.vmChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, _size)
    _vs = l.vmChild("c", "ns", {provider = "vsphere", distribution = "k3s", size = "medium"}, _size)
    assert _px.kind == "NativeProxmoxVM"
    assert _px.spec.vm.memory == "8192"
    assert "ram" not in _px.spec.vm
    assert _vs.kind == "NativeVsphereVM"
    assert _vs.spec.vm.ram == "8192"
    assert "memory" not in _vs.spec.vm
}

# vSphere has no cloudInit block in its XRD at all — emitting one would be a
# schema error on the composed resource.
test_only_proxmox_gets_cloudinit = lambda {
    _size = cat.getSize("medium")
    assert "cloudInit" in l.vmChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, _size).spec
    assert "cloudInit" not in l.vmChild("c", "ns", {provider = "vsphere", distribution = "k3s", size = "medium"}, _size).spec
}

test_vm_name_follows_clusterName_not_xr_name = lambda {
    _size = cat.getSize("small")
    _r = l.vmChild("xr-name", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", clusterName = "u26-kind1"}, _size)
    assert _r.spec.vm.name == "u26-kind1"
    assert _r.metadata.name == "xr-name-vm"

    # The hostname var is what actually sets the guest hostname on Proxmox —
    # bpg cloud-init cannot without a snippets datastore.
    assert "vm_hostname+-u26-kind1" in _r.spec.ansible.varsFile
}

# --- the ansible stages ----------------------------------------------------
test_distribution_run_carries_the_catalog_vars_and_cluster_name = lambda {
    _r = l.distributionRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", clusterName = "k1"}, "10.0.0.1")
    assert _r.spec.ansiblePlaybooks == ["sthings.rke.k3s_cluster"]
    # Without this the cluster has no pod network at all.
    assert "install_cilium+-true" in _r.spec.ansibleVarsFile
    assert "cluster_name+-k1" in _r.spec.ansibleVarsFile
    assert _r.spec.ansibleVarsInventory[0] == 'initial_master_node+["10.0.0.1"]'
}

test_kubeconfig_run_is_a_separate_run_with_the_k3s_path = lambda {
    _r = l.kubeconfigRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, "10.0.0.1")
    assert _r.spec.ansiblePlaybooks == ["sthings.container.upload_kubeconfig_vault"]
    assert "kubeconfig_path+-/etc/rancher/k3s/k3s.yaml" in _r.spec.ansibleVarsFile
    # kind writes elsewhere, so it must NOT get the k3s server path.
    _k = l.kubeconfigRun("c", "ns", {provider = "proxmox", distribution = "kind", size = "medium"}, "10.0.0.1")
    assert "kubeconfig_path+-/etc/rancher/k3s/k3s.yaml" not in _k.spec.ansibleVarsFile
}

# rke2 writes to its OWN path. The upload play's default is a kind path
# (/home/<user>/.kube/<kind_cluster_name>, defaulting to `dev`), so without an
# override an rke2 cluster's upload looks for a file that does not exist —
# confirmed on the reference-run VM, which has /etc/rancher/rke2/rke2.yaml and
# no k3s path at all. Same shape as crossplane-configurations#232.
test_rke2_gets_its_own_kubeconfig_path = lambda {
    _r = l.kubeconfigRun("c", "ns", {provider = "proxmox", distribution = "rke2", size = "medium"}, "10.0.0.1")
    assert "kubeconfig_path+-/etc/rancher/rke2/rke2.yaml" in _r.spec.ansibleVarsFile
    # And emphatically not the k3s one — they are different directories.
    assert "kubeconfig_path+-/etc/rancher/k3s/k3s.yaml" not in _r.spec.ansibleVarsFile
}

# The catalog entry has to survive the whole distribution stage, not just exist.
test_rke2_distribution_run_carries_the_verified_pins = lambda {
    _r = l.distributionRun("c", "ns", {provider = "proxmox", distribution = "rke2", size = "medium", clusterName = "r1"}, "10.0.0.1")
    assert _r.spec.ansiblePlaybooks == ["sthings.rke.rke2_cluster"]
    # The fleet pair, not the play defaults (1.36.1 / rke2r2).
    assert "rke2_k8s_version+-1.35.1" in _r.spec.ansibleVarsFile
    assert "rke2_release_kind+-rke2r1" in _r.spec.ansibleVarsFile
    # rke2_cni: none means the role must bring cilium, or there is no pod network.
    assert "install_cilium+-true" in _r.spec.ansibleVarsFile
    assert "cluster_name+-r1" in _r.spec.ansibleVarsFile
    # Same role as k3s, so the same three groups.
    assert _r.spec.ansibleVarsInventory[0] == 'initial_master_node+["10.0.0.1"]'
}

# rke2 owns its CNI, so a Platform must NOT add one — the k3s rule, not the kind one.
test_rke2_platform_does_not_add_a_second_cni = lambda {
    assert not cat.platformCniEnabled("rke2")
}

# THE kind BUG (crossplane-configurations#232). sthings.container.kind ignores
# `cluster_name` and names the cluster from `kind_cluster_name`, defaulting it to
# `dev` — so the XR's identity never reached the cluster, and the Cni child then
# aimed cilium at `<clusterName>-control-plane`, a container that never existed.
test_kind_gets_its_cluster_name_in_the_var_the_play_reads = lambda {
    _spec = {provider = "proxmox", distribution = "kind", size = "medium", clusterName = "kindstack-test"}
    _d = l.distributionRun("c", "ns", _spec, "10.0.0.1")
    assert "kind_cluster_name+-kindstack-test" in _d.spec.ansibleVarsFile
    # cluster_name stays: the upload stage uses it as the Vault secret name.
    assert "cluster_name+-kindstack-test" in _d.spec.ansibleVarsFile

    # BOTH stages, or the accidental agreement breaks: upload_kubeconfig_vault
    # derives kubeconfig_path from kind_cluster_name and would keep defaulting to
    # /home/sthings/.kube/dev while the cluster moved to the real name.
    _k = l.kubeconfigRun("c", "ns", _spec, "10.0.0.1")
    assert "kind_cluster_name+-kindstack-test" in _k.spec.ansibleVarsFile
    assert "cluster_name+-kindstack-test" in _k.spec.ansibleVarsFile
}

# The kind cluster name must equal the name the Cni child derives its
# k8sServiceHost from, or cilium deadlocks — that equality IS the fix, so assert
# it against the Platform child rather than trusting two separate constants.
test_kind_cluster_name_matches_the_platform_cluster_name = lambda {
    _spec = {provider = "proxmox", distribution = "kind", size = "medium", clusterName = "kindstack-test"}
    _p = l.platformChild("c", "ns", _spec, "")
    assert "kind_cluster_name+-{}".format(_p.spec.clusterName) in l.distributionRun("c", "ns", _spec, "10.0.0.1").spec.ansibleVarsFile
    # Same when clusterName is defaulted from the XR name.
    _bare = {provider = "proxmox", distribution = "kind", size = "medium"}
    assert "kind_cluster_name+-c" in l.distributionRun("c", "ns", _bare, "10.0.0.1").spec.ansibleVarsFile
    assert l.platformChild("c", "ns", _bare, "").spec.clusterName == "c"
}

# k3s takes the name through cluster_name, which every stage already carries; an
# alias there would emit a var no play reads.
test_k3s_gets_no_kind_cluster_name = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", clusterName = "k1"}
    assert len([1 for v in l.distributionRun("c", "ns", _spec, "10.0.0.1").spec.ansibleVarsFile if v.startswith("kind_cluster_name")]) == 0
    assert len([1 for v in l.kubeconfigRun("c", "ns", _spec, "10.0.0.1").spec.ansibleVarsFile if v.startswith("kind_cluster_name")]) == 0
}

# runID is the supported way to force a deliberate re-run; it must reach BOTH
# derived names, because provider-kubernetes only creates a new PipelineRun for
# a new Object.
test_runid_suffixes_both_names = lambda {
    _r = l.distributionRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", runIDs = {distribution = "2"}}, "10.0.0.1")
    assert _r.spec.pipelineRunName == "c-distribution-2"
    assert _r.spec.crossplaneObjectName == "c-distribution-2"

    # The composed-resource name must NOT move, or bumping runID would orphan
    # the previous child instead of replacing the run.
    assert _r.metadata.name == "c-distribution"
}

test_no_runid_keeps_the_plain_names = lambda {
    _r = l.distributionRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, "10.0.0.1")
    assert _r.spec.pipelineRunName == "c-distribution"
}

# --- the platform child ----------------------------------------------------
# THE rule this whole thing exists to enforce: cni.enabled follows from the
# distribution, never from the user. A k3s role installs cilium itself; setting
# it by hand is how a cluster ends up with two CNIs.
test_platform_cni_follows_the_distribution = lambda {
    assert not l.platformChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, "").spec.cni.enabled
    assert l.platformChild("c", "ns", {provider = "proxmox", distribution = "kind", size = "medium"}, "").spec.cni.enabled
}

test_user_cannot_override_cni_enabled = lambda {
    _r = l.platformChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", platform = {
        cni = {enabled = True, chart = {version = "1.19.6"}}
    }}, "")
    # The user's enabled is discarded...
    assert not _r.spec.cni.enabled
    # ...but the rest of their cni block survives.
    assert _r.spec.cni.chart.version == "1.19.6"
}

test_platform_passthrough_and_derived_clusterName = lambda {
    _r = l.platformChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", clusterName = "k1", platform = {
        fluxInit = {enabled = True}
    }}, "")
    assert _r.spec.clusterName == "k1"
    assert _r.spec.fluxInit.enabled
}

# --- teardown --------------------------------------------------------------
# `of` dies LAST, `by` dies first. Getting these backwards is the difference
# between an ordered teardown and Objects stuck on finalizers against a dead
# API server.
test_usage_protects_the_vm_from_the_platform = lambda {
    _u = l.usage("NativeProxmoxVM", "c-vm", "Platform", "c-platform", "platform-uses-vm", True, "c")
    assert _u.spec.of.kind == "NativeProxmoxVM"
    assert _u.spec.by.kind == "Platform"
    assert _u.spec.replayDeletion
}

test_usage_resolves_the_group_per_kind = lambda {
    assert l.usage("NativeVsphereVM", "a", "Platform", "b", "u", True, "c").spec.of.apiVersion == "resources.stuttgart-things.com/v1alpha1"
    assert l.usage("ClusterAccess", "a", "Platform", "b", "u", True, "c").spec.of.apiVersion == "config.stuttgart-things.com/v1alpha1"

    # The teardown guard points at the COMPOSITE, which lives in the same group
    # as ClusterAccess and Platform — so it needs no special case in the lambda.
    assert l.usage("ClusterStack", "a", "Platform", "b", "u", False, "c").spec.of.apiVersion == "config.stuttgart-things.com/v1alpha1"
}

# The guard that makes a one-phase teardown impossible rather than silently
# lossy. replayDeletion MUST stay false on it: replay re-issues a blocked delete
# once the blocker is gone, which is convenient for a child and dangerous for
# the whole stack — an abandoned `kubectl delete` would turn a later, unrelated
# `platformEnabled: false` into a surprise teardown of the entire cluster.
test_stack_guard_does_not_replay_deletion = lambda {
    _g = l.usage("ClusterStack", "c", "Platform", "c-platform", "stack-uses-platform", False, "c")
    assert _g.spec.of.kind == "ClusterStack"
    assert _g.spec.of.resourceRef.name == "c"
    assert _g.spec.by.kind == "Platform"
    assert not _g.spec.replayDeletion
}

# --- the kubeconfigs Vault -------------------------------------------------
# The name must be EMITTED, not left to ansible-run's default: which Vault the
# upload authenticates against is this module's decision, and an unset field
# would follow a downstream default change silently.
#
# The value is `vault` — the fleet's vault-vsphere credential, which owns the
# kubeconfigs KV mount. Until 0.4.1 this asserted `vault-kubeconfigs`, a Secret
# nothing has ever created: sops-git-secrets names a Secret from metadata.name
# inside its blob, so that name required a fourth blob duplicating a credential
# already present as `vault` (sha256-identical on kind3, 2026-08-12). The upload
# failed with "failed to determine alias name from login request" on every fresh
# machinery cluster until someone hand-made the alias.
test_kubeconfig_run_targets_the_kubeconfigs_vault = lambda {
    _r = l.kubeconfigRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, "10.0.0.1")
    assert _r.spec.vaultSecretName == "vault"
}

# The ClusterAccess side keeps the name `vault-kubeconfigs`, and that is not an
# oversight: it is a ClusterProviderConfig emitted by the provider-kubeconfig-vault
# chart, not a Secret. Asserted next to the change above so nobody "harmonises"
# the two names in either direction.
test_cluster_access_provider_config_is_not_the_secret_name = lambda {
    _a = l.clusterAccess("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"})
    assert _a.spec.kubeconfigProviderConfigRef == "vault-kubeconfigs"
    _r = l.kubeconfigRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, "10.0.0.1")
    assert _r.spec.vaultSecretName != _a.spec.kubeconfigProviderConfigRef
}

test_kubeconfig_vault_secret_is_overridable = lambda {
    _r = l.kubeconfigRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", kubeconfig = {vaultSecretName = "other-vault"}}, "10.0.0.1")
    assert _r.spec.vaultSecretName == "other-vault"
}

# The distribution run talks to no Vault, so it must not carry a secret name at
# all — an unset field keeps the rendered params byte-identical to before.
test_distribution_run_has_no_vault_secret = lambda {
    _r = l.distributionRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, "10.0.0.1")
    assert "vaultSecretName" not in _r.spec
}

# A re-run must not spread. Bumping one stage's id renames that stage only —
# the first live build proved the alternative: a single global runID re-ran the
# k3s install while repairing the kubeconfig upload.
test_runid_is_per_stage = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", runIDs = {kubeconfig = "3"}}
    assert l.kubeconfigRun("c", "ns", _spec, "10.0.0.1").spec.pipelineRunName == "c-kubeconfig-3"
    assert l.distributionRun("c", "ns", _spec, "10.0.0.1").spec.pipelineRunName == "c-distribution"
}

test_runid_lookup_tolerates_missing_stage = lambda {
    assert l.runIDFor({}, "distribution") == ""
    assert l.runIDFor({
        runIDs = {kubeconfig = "1"}
    }, "distribution") == ""
}

# The catalog's version pins must actually reach the rendered run. A pin nobody
# passes through is decoration — and this is the drift #186 was about.
test_distribution_run_carries_the_version_pins = lambda {
    _r = l.distributionRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}, "10.0.0.1")
    assert "k3s_k8s_version+-1.35.1" in _r.spec.ansibleVarsFile
    assert "k3s_release_kind+-k3s1" in _r.spec.ansibleVarsFile
}

# --- per-stage ansible overrides -------------------------------------------
# The shared list reaches every stage; a stage entry is merged OVER it. Without
# this, pinning a collection for the base-OS stage silently replaced the set the
# k3s stage needed -- on the first live build that forced restating sthings-rke
# in order to bump sthings-baseos.
test_stage_overrides_merge_over_the_shared_ansible_block = lambda {
    _spec = {
        provider = "proxmox"
        distribution = "k3s"
        size = "medium"
        ansible = {
            extraCollections = ["shared:1"]
            pipelineNamespace = "tekton-ci"
            stages = {
                baseos = {extraCollections = ["baseos:2"]}
            }
        }
    }
    # the base-OS stage sees its own list...
    assert l.vmChild("c", "ns", _spec, cat.getSize("small")).spec.ansible.extraCollections == ["baseos:2"]
    # ...the distribution stage still sees the shared one...
    assert l.distributionRun("c", "ns", _spec, "10.0.0.1").spec.ansibleExtraCollections == ["shared:1"]
    # ...and unrelated shared keys survive the merge.
    assert l.distributionRun("c", "ns", _spec, "10.0.0.1").spec.namespace == "tekton-ci"
}

test_no_stage_overrides_keeps_the_shared_list_everywhere = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", ansible = {extraCollections = ["only:1"]}}
    assert l.vmChild("c", "ns", _spec, cat.getSize("small")).spec.ansible.extraCollections == ["only:1"]
    assert l.kubeconfigRun("c", "ns", _spec, "10.0.0.1").spec.ansibleExtraCollections == ["only:1"]
}

# --- the hostname floor ----------------------------------------------------
# vm_hostname needs sthings-baseos >= 26.5.695. On an older set it is silently
# ignored, so this is a knob rather than a hard-wire -- a fleet on an older pin
# can turn it off and know why, instead of wondering why the hostname is unset.
test_hostname_var_is_set_by_default = lambda {
    _r = l.vmChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", clusterName = "k1"}, cat.getSize("small"))
    assert "vm_hostname+-k1" in _r.spec.ansible.varsFile
}

test_hostname_var_can_be_turned_off = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", clusterName = "k1", ansible = {setHostname = False}}
    _r = l.vmChild("c", "ns", _spec, cat.getSize("small"))
    assert len([v for v in _r.spec.ansible.varsFile if "vm_hostname" in v]) == 0
    # the other base-OS vars must survive
    assert "manage_filesystem+-true" in _r.spec.ansible.varsFile
}

# Regression: `|` unifies rather than overrides, so a key holding a LIST on both
# sides raised "conflicting values on the attribute extraCollections" — but only
# when rendering a real XR, not with the literal dicts the other tests use.
# Asserting the winning value is not enough; the merge must not raise at all.
test_stage_override_replaces_a_list_without_conflict = lambda {
    _spec = {
        provider = "proxmox"
        distribution = "k3s"
        size = "medium"
        ansible = {
            extraCollections = ["shared:1", "shared:2"]
            extraVars = ["a+-1"]
            stages = {
                distribution = {extraCollections = ["dist:1"]}
            }
        }
    }
    _d = l.stageAnsible(_spec, "distribution")
    assert _d.extraCollections == ["dist:1"]
    assert _d.extraVars == ["a+-1"]
}

# --- the API endpoint (#171) -----------------------------------------------
# Every Platform in the fleet states vaultIssuer.kubernetesHost by hand today --
# a copied node IP that goes stale the moment the machine is rebuilt, with
# nothing noticing until an issuer breaks. ClusterAccess discovers it, so derive
# it. This does NOT make the endpoint highly available; it removes the
# hand-copied value, not the single point of failure.
test_kubernetes_host_is_derived_when_unset = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", platform = {
        vaultIssuer = {enabled = True, pkiRole = "sthings-vsphere"}
    }}
    _r = l.platformChild("c", "ns", _spec, "https://10.0.0.9:6443")
    assert _r.spec.vaultIssuer.kubernetesHost == "https://10.0.0.9:6443"
    # the rest of the user's block survives
    assert _r.spec.vaultIssuer.pkiRole == "sthings-vsphere"
}

# An explicit value may deliberately differ -- a VIP or a load balancer in front
# of the API. Deriving over it would silently undo that.
test_explicit_kubernetes_host_wins = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", platform = {
        vaultIssuer = {enabled = True, kubernetesHost = "https://api.example.com:6443"}
    }}
    _r = l.platformChild("c", "ns", _spec, "https://10.0.0.9:6443")
    assert _r.spec.vaultIssuer.kubernetesHost == "https://api.example.com:6443"
}

test_no_vault_issuer_means_no_injection = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", platform = {
        fluxInit = {enabled = True}
    }}
    _r = l.platformChild("c", "ns", _spec, "https://10.0.0.9:6443")
    assert "vaultIssuer" not in _r.spec
}

# No endpoint discovered yet (ClusterAccess not ready) must not inject an empty
# host -- that would be worse than leaving it unset.
test_no_endpoint_means_no_injection = lambda {
    _spec = {provider = "proxmox", distribution = "k3s", size = "medium", platform = {
        vaultIssuer = {enabled = True}
    }}
    _r = l.platformChild("c", "ns", _spec, "")
    assert "kubernetesHost" not in _r.spec.vaultIssuer
}

test_platform_domain_is_lifted = lambda {
    _plat = {
        status = {
            components = {
                ipReservation = {domain = "u26-rke2-1.sthings-vsphere.labul.sva.de"}
            }
        }
    }
    assert l.platformDomain(_plat) == "u26-rke2-1.sthings-vsphere.labul.sva.de"
}

# Every shape that means "no domain yet" must yield "", so the caller can omit
# the field. A blank domain substituted into a Gateway hostname or a certificate
# renders as a valid-looking empty value — worse than an absent one.
test_platform_domain_absent_is_empty = lambda {
    assert l.platformDomain({}) == ""
    assert l.platformDomain({
        status = {}
    }) == ""
    assert l.platformDomain({
        status = {
            components = {}
        }
    }) == ""
    assert l.platformDomain({
        status = {
            components = {
                ipReservation = {enabled = False}
            }
        }
    }) == ""
}

# The ManagementPlane child passes through verbatim and gets only clusterName
# added — the one thing this Composition knows and the user should not repeat.
test_management_plane_child_passes_through = lambda {
    _spec = {clusterName = "mgmt-1", managementPlane = {profile = "machinery", clusterAdminRbac = True}}
    _c = l.managementPlaneChild("stack-1", "default", _spec)
    assert _c.kind == "ManagementPlane"
    assert _c.metadata.name == "stack-1-management-plane"
    assert _c.metadata.namespace == "default"
    assert _c.spec.profile == "machinery", "arbitrary keys reach the child untouched"
    assert _c.spec.clusterAdminRbac
    assert _c.spec.clusterName == "mgmt-1"
}

# clusterName falls back to the stack's own name, matching platformChild.
test_management_plane_child_defaults_cluster_name = lambda {
    _c = l.managementPlaneChild("stack-1", "default", {})
    assert _c.spec.clusterName == "stack-1"
}

# A clusterName inside the passthrough block must not win over the Composition's
# — it is the one field this layer owns, and two sources would let a child point
# at a different cluster than the stack that built it.
test_management_plane_child_ignores_a_passed_cluster_name = lambda {
    _spec = {clusterName = "right", managementPlane = {clusterName = "wrong"}}
    _c = l.managementPlaneChild("stack-1", "default", _spec)
    assert _c.spec.clusterName == "right"
}

# --- Usage object names must be namespace-unique ----------------------------

# THE bug this guards. Until 0.7.0 the Usage was named after its label alone —
# `access-uses-vm`, `platform-uses-vm`, … — with no cluster in it, while every
# resource it REFERENCES carried the cluster name. So the first ClusterStack in
# a namespace owned those object names and every later one failed to apply:
#
#   Usage.protection.crossplane.io "access-uses-vm" is invalid:
#   metadata.ownerReferences: Invalid value: [... ClusterStack "<the-first>"]
#
# Kubernetes refuses a second controller owner. The later stack then sits at
# Synced=False indefinitely while its own status.ready still says true, so it
# reads as finished — which is how one went 26 hours unnoticed on kind3.
test_usage_object_name_carries_the_cluster = lambda {
    _a = l.usage("NativeProxmoxVM", "a-vm", "ClusterAccess", "a-access", "access-uses-vm", True, "a")
    _b = l.usage("NativeProxmoxVM", "b-vm", "ClusterAccess", "b-access", "access-uses-vm", True, "b")
    assert _a.metadata.name != _b.metadata.name, "two clusters must not collide on one object"
    assert _a.metadata.name == "a-access-uses-vm"
    assert _b.metadata.name == "b-access-uses-vm"
}

# The label stays the composition-resource-name. It identifies the Usage WITHIN
# the composition, so renaming the object must not renumber it — otherwise
# every existing stack would churn its resource identity on upgrade.
test_composition_resource_name_is_unprefixed = lambda {
    _u = l.usage("NativeProxmoxVM", "a-vm", "ClusterAccess", "a-access", "access-uses-vm", True, "a")
    assert _u.metadata.annotations["krm.kcl.dev/composition-resource-name"] == "access-uses-vm"
}

# All five labels, not just the one that was caught. `prefix` is a required
# positional argument now, so no call site can omit it — this covers the other
# half: that each label yields a distinct, cluster-scoped object name.
test_every_usage_label_is_prefixed = lambda {
    _labels = ["platform-uses-vm", "platform-uses-access", "access-uses-vm", "stack-uses-platform", "mgmt-uses-vm", "mgmt-uses-access", "stack-uses-mgmt"]
    _names = [l.usage("NativeProxmoxVM", "zeta-vm", "Platform", "zeta-platform", lb, True, "zeta").metadata.name for lb in _labels]
    assert all n in _names {n.startswith("zeta-")}, "every Usage object name carries the cluster"
    assert len(_names) == len({n: True for n in _names}), "and they stay distinct from each other"
}

# extraVars must reach EVERY stage, not just the two that happened to be wired.
# It was missing from kubeconfigRun, so an override aimed at the upload — the
# KV mount under secret_path_kubeconfig is the one people actually want to
# change — disappeared with no error anywhere: the XRD documents the field, the
# value is accepted, and the rendered varsFile simply does not carry it.
test_extra_vars_reach_the_kubeconfig_stage = lambda {
    _spec = {
        provider = "proxmox"
        distribution = "rke2"
        size = "medium"
        ansible = {
            stages = {
                kubeconfig = {extraVars = ["secret_path_kubeconfig+-cicd-kubeconfigs"]}
            }
        }
    }
    _vars = l.kubeconfigRun("c", "ns", _spec, "10.0.0.1").spec.ansibleVarsFile
    assert "secret_path_kubeconfig+-cicd-kubeconfigs" in _vars
    # the catalog's own vars survive alongside it
    assert "kubeconfig_path+-/etc/rancher/rke2/rke2.yaml" in _vars
}

# The shared block reaches the kubeconfig stage too, not only a per-stage one.
test_shared_extra_vars_reach_the_kubeconfig_stage = lambda {
    _spec = {
        provider = "proxmox"
        distribution = "rke2"
        size = "medium"
        ansible = {extraVars = ["shared_var+-1"]}
    }
    assert "shared_var+-1" in l.kubeconfigRun("c", "ns", _spec, "10.0.0.1").spec.ansibleVarsFile
}

test_read_ref_is_derived_from_the_upload_target = lambda {
    """providerConfigRef folgt vaultSecretName, wenn es nicht gesetzt ist.

    Bis 0.8.0 waren beide getrennte Felder mit Defaults, die nur zufaellig
    zusammenpassten. vaultSecretName: vault-infra gegen den Default
    vault-kubeconfigs (= vault-vsphere) liess den RemoteCluster im falschen
    Vault suchen; der Bau stand 40 Minuten, ohne dass eine Ressource darueber
    einen Fehler meldete. crossplane-configurations#336.
    """
    assert l.kubeconfigReadRef({}) == "vault-kubeconfigs"
    assert l.kubeconfigReadRef({vaultSecretName = "vault"}) == "vault-kubeconfigs"
    assert l.kubeconfigReadRef({vaultSecretName = "vault-infra"}) == "vault-kubeconfigs-infra"
    assert l.kubeconfigReadRef({vaultSecretName = "vault-labda"}) == "vault-kubeconfigs-labda"
}

test_labda_pair_needs_no_explicit_ref = lambda {
    """LabDA ohne providerConfigRef von Hand.

    Der Punkt des Map-Eintrags: ein LabDA-ClusterStack nennt nur
    vaultSecretName, und die Leseseite folgt. Wer hier von Hand nachhelfen
    muesste, koennte die beiden Seiten wieder auseinanderlaufen lassen -- der
    Fehler aus #336, der 40 Minuten gekostet hat, weil der ClusterStack dabei
    Ready=True bleibt.
    """
    _spec = {clusterName = "seed", kubeconfig = {vaultSecretName = "vault-labda"}}
    _a = l.clusterAccess("seed", "crossplane-system", _spec)
    assert _a.spec.kubeconfigProviderConfigRef == "vault-kubeconfigs-labda"
}

test_explicit_read_ref_still_wins = lambda {
    """Der Notausgang bleibt: eine Vault-Paarung, die die Map nicht kennt."""
    assert l.kubeconfigReadRef({vaultSecretName = "vault-infra", providerConfigRef = "sonderfall"}) == "sonderfall"
    assert l.kubeconfigReadRef({providerConfigRef = "sonderfall"}) == "sonderfall"
}

test_unknown_upload_target_falls_back_instead_of_guessing = lambda {
    """Unbekanntes vaultSecretName -> historischer Default, nicht geraten.

    Weiterraten hiesse, Namen zu erfinden; die XRD lehnt stattdessen die zwei
    Kombinationen ab, von denen wir wissen, dass sie falsch sind.
    """
    assert l.kubeconfigReadRef({vaultSecretName = "vault-irgendwas"}) == "vault-kubeconfigs"
}

test_access_xr_carries_the_derived_ref = lambda {
    """Und es kommt auch wirklich an der ClusterAccess-XR an."""
    _a = l.clusterAccess("c", "default", {clusterName = "c", kubeconfig = {vaultSecretName = "vault-infra"}})
    assert _a.spec.kubeconfigProviderConfigRef == "vault-kubeconfigs-infra"
}

test_harvester_vm_is_composed_with_its_own_shape = lambda {
    """Harvester ist nicht nur ein anderer Name — die Form ist anders.

    Boot-Disk als eigenes PVC, cpu als Objekt, Speicher als Quantity-String,
    cloud-init mit Pflichtfeldern. crossplane-configurations#258 Block B.
    """
    _v = l.vmChild("c1", "default", {provider = "harvester", clusterName = "c1"}, cat.getSize("medium"))
    assert _v.kind == "HarvesterVM"
    assert _v.apiVersion == "resources.stuttgart-things.com/v1alpha1"
    assert _v.spec.volume.pvcName == "c1-disk-0"
    assert _v.spec.volume.storage == "64Gi"
    assert _v.spec.vm.cpu.cores == 4
    assert _v.spec.vm.resources.cpu == "4"
    assert _v.spec.vm.resources.memory == "8192Mi"
    assert _v.spec.cloudInit.vmName == "c1"
    assert _v.spec.cloudInit.hostname == "c1"
}

test_harvester_switches_ansible_on = lambda {
    """ansible.enabled ist bei HarvesterVM per Default FALSE.

    Bliebe es aus, kaeme die VM nackt hoch — kein Base-OS, kein Kubernetes —
    und der ClusterStack wartete ewig auf eine Stufe, die nie emittiert wurde.
    """
    _v = l.vmChild("c1", "default", {provider = "harvester", clusterName = "c1"}, cat.getSize("medium"))
    assert _v.spec.ansible.enabled == True
}

test_harvester_usage_points_at_the_right_group = lambda {
    """Die Usage muss resources.* sagen, nicht config.*.

    Ein falscher apiVersion faellt nicht auf: die Usage entsteht, zeigt auf ein
    kind, das es nicht gibt, und schuetzt still gar nichts.
    """
    _u = l.usage("HarvesterVM", "c1-vm", "ClusterAccess", "c1-access", "access-uses-vm", True, "c1")
    assert _u.spec.of.apiVersion == "resources.stuttgart-things.com/v1alpha1"
    assert _u.spec.of.kind == "HarvesterVM"
}

test_proxmox_stays_the_default = lambda {
    """Ein unbekannter oder fehlender provider bleibt proxmox."""
    _v = l.vmChild("c1", "default", {clusterName = "c1"}, cat.getSize("small"))
    assert _v.kind == "NativeProxmoxVM"
}
