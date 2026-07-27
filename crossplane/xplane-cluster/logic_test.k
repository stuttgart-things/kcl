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

# runID is the supported way to force a deliberate re-run; it must reach BOTH
# derived names, because provider-kubernetes only creates a new PipelineRun for
# a new Object.
test_runid_suffixes_both_names = lambda {
    _r = l.distributionRun("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", runID = "2"}, "10.0.0.1")
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
    assert not l.platformChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium"}).spec.cni.enabled
    assert l.platformChild("c", "ns", {provider = "proxmox", distribution = "kind", size = "medium"}).spec.cni.enabled
}

test_user_cannot_override_cni_enabled = lambda {
    _r = l.platformChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", platform = {
        cni = {enabled = True, chart = {version = "1.19.6"}}
    }})
    # The user's enabled is discarded...
    assert not _r.spec.cni.enabled
    # ...but the rest of their cni block survives.
    assert _r.spec.cni.chart.version == "1.19.6"
}

test_platform_passthrough_and_derived_clusterName = lambda {
    _r = l.platformChild("c", "ns", {provider = "proxmox", distribution = "k3s", size = "medium", clusterName = "k1", platform = {
        fluxInit = {enabled = True}
    }})
    assert _r.spec.clusterName == "k1"
    assert _r.spec.fluxInit.enabled
}

# --- teardown --------------------------------------------------------------
# `of` dies LAST, `by` dies first. Getting these backwards is the difference
# between an ordered teardown and Objects stuck on finalizers against a dead
# API server.
test_usage_protects_the_vm_from_the_platform = lambda {
    _u = l.usage("NativeProxmoxVM", "c-vm", "Platform", "c-platform", "platform-uses-vm")
    assert _u.spec.of.kind == "NativeProxmoxVM"
    assert _u.spec.by.kind == "Platform"
    assert _u.spec.replayDeletion
}

test_usage_resolves_the_group_per_kind = lambda {
    assert l.usage("NativeVsphereVM", "a", "Platform", "b", "u").spec.of.apiVersion == "resources.stuttgart-things.com/v1alpha1"
    assert l.usage("ClusterAccess", "a", "Platform", "b", "u").spec.of.apiVersion == "config.stuttgart-things.com/v1alpha1"
}
