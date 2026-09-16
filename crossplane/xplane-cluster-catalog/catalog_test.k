# Unit tests for the cluster catalog. Run with `kcl test`.
# These validate the catalog's own invariants — no Crossplane, no cluster.
import .main as c

test_distributions_registered = lambda {
    assert "k3s" in c.distributions
    assert "kind" in c.distributions

    # rke2 joined on 2026-08-11, in the same commit as its reference run — an
    # AnsibleRun on u26-kind3 that brought up v1.35.1+rke2r1 with cilium. The
    # rule this assertion used to enforce ("no entry without a reference run")
    # was satisfied, not waived.
    assert "rke2" in c.distributions
}

# rke2 pins the pair the FLEET runs, not the pair the play defaults to
# (1.36.1 / rke2r2). A catalog that ships an unbooted combination is the exact
# failure k3s.k documents, so the two values are asserted rather than trusted.
test_rke2_pins_the_verified_version_pair = lambda {
    _v = c.getDistribution("rke2").vars
    assert _v["rke2_k8s_version"] == "1.35.1"
    assert _v["rke2_release_kind"] == "rke2r1"
}

# rke2 is told to ship no CNI, so its role must install cilium — and a Platform
# for such a cluster must therefore NOT enable its own Cni component. Same shape
# as k3s, opposite of kind.
test_rke2_owns_its_own_cni = lambda {
    _d = c.getDistribution("rke2")
    assert _d.vars["rke2_cni"] == "none"
    assert _d.vars["install_cilium"] == "true"
    assert _d.cniOwnership == "self"
    assert not c.platformCniEnabled("rke2")
}

test_sizes_registered = lambda {
    assert c.getSize("small").cpu == "2"
    assert c.getSize("medium").memory == "8192"
    assert c.getSize("large").disk == "100"
}

test_unknown_names_fail_loudly = lambda {
    # Cannot assert on the failure itself in KCL, so assert the precondition the
    # error message is built from: the known-name lists are non-empty and sorted.
    assert len(c.distributionNames) > 0
    assert len(c.sizeNames) > 0
    assert c.distributionNames == sorted(c.distributionNames)
}

# --- The rule this catalog exists to make checkable ------------------------
# "A k3s cluster must NOT get a Platform CNI; a kind cluster must." Until now
# that lived only as a prose comment in two XR files.
test_cni_ownership_is_opposite_for_k3s_and_kind = lambda {
    assert c.getDistribution("k3s").cniOwnership == "self"
    assert c.getDistribution("kind").cniOwnership == "platform"
    assert not c.platformCniEnabled("k3s")
    assert c.platformCniEnabled("kind")
}

# k3s writes flannel-backend=none + disable-kube-proxy=true, so the role MUST
# install cilium. A k3s entry without it produces a cluster with no pod network
# at all — the exact failure that made ansible/exec/labul/k3s-target-k3s useless.
test_k3s_installs_cilium = lambda {
    assert c.getDistribution("k3s").vars["install_cilium"] == "true"
}

# The role branches on groups['initial_master_node'] and
# groups['additional_master_nodes']; a flat `all` inventory fails with an
# undefined group.
test_k3s_declares_the_required_inventory_groups = lambda {
    _g = c.getDistribution("k3s").inventoryGroups
    assert "initial_master_node" in _g
    assert "additional_master_nodes" in _g
    assert "workers" in _g
}

# kind must not rebuild on every reconcile (it would move the API port) and must
# rewrite the kubeconfig address away from 0.0.0.0, which the API server cert is
# not valid for.
test_kind_is_reconcile_safe = lambda {
    _v = c.getDistribution("kind").vars
    assert _v["rebuild_kind_cluster"] == "false"
    assert _v["update_kubeconfig_ip"] == "true"
}

# The kind play names its cluster from `kind_cluster_name`, NOT `cluster_name` —
# with only the latter set it silently built `dev` and the Platform's Cni child
# then aimed cilium at `<clusterName>-control-plane`, a container that does not
# exist (crossplane-configurations#232).
test_kind_declares_its_own_cluster_name_var = lambda {
    assert c.getDistribution("kind").clusterNameVars == ["kind_cluster_name"]

    # k3s takes the name through `cluster_name`, which every stage already
    # carries — an extra alias there would be noise, not safety.
    assert c.getDistribution("k3s").clusterNameVars == []
}

# `cluster_name` is added by the consumer for the Vault path; a distribution
# re-declaring it here would emit the same key twice into one varsFile.
test_cluster_name_is_never_restated_as_an_alias = lambda {
    assert len([1 for _, d in c.distributions if "cluster_name" in d.clusterNameVars]) == 0
    assert len([1 for _, d in c.distributions if len([k for k in d.clusterNameVars if k in d.vars]) > 0]) == 0
}

# --- Multi-node gating -----------------------------------------------------
test_multi_node_sizes_are_rejected_by_single_node_distributions = lambda {
    # Both current distributions are single-node only, so every size with
    # masters > 1 must be unbuildable through them. assertSizeSupported would
    # fail the render; here we assert the data it decides on.
    assert not c.getDistribution("k3s").multiNode
    assert not c.getDistribution("kind").multiNode
    assert c.getSize("medium-ha").masters == 3
}

test_single_node_sizes_are_supported = lambda {
    assert c.assertSizeSupported("k3s", "medium")
    assert c.assertSizeSupported("kind", "large")
}

# --- Shared stage ----------------------------------------------------------
# The kubeconfig upload is its own stage precisely so it can be re-run without
# re-running the cluster build; if it ever migrates into a distribution's
# playbooks, that is a regression worth failing on.
test_kubeconfig_upload_is_a_separate_stage = lambda {
    assert c.kubeconfigStage.playbooks == ["sthings.container.upload_kubeconfig_vault"]
    # KCL has no for-statement inside a lambda; count via a comprehension.
    assert len([1 for _, d in c.distributions if "sthings.container.upload_kubeconfig_vault" in d.playbooks]) == 0
}

# Sizes are consumed as strings by both VM XRDs; an int would fail schema
# validation on the composed resource.
test_size_values_are_strings = lambda {
    assert len([1 for _, s in c.sizes if typeof(s.cpu) != "str" or typeof(s.memory) != "str" or typeof(s.disk) != "str"]) == 0
}

# --- version pinning -------------------------------------------------------
# An unpinned distribution means two clusters built from the same profile can
# run different Kubernetes versions depending on the day they were built. A
# live build produced v1.36.1 where the hand-written XR pins 1.35.1.
test_k3s_pins_its_kubernetes_version = lambda {
    _v = c.getDistribution("k3s").vars
    assert _v["k3s_k8s_version"] == "1.35.1"
    assert _v["k3s_release_kind"] == "k3s1"
}

# kind pins the KIND BINARY, not Kubernetes — the k8s version follows from the
# node image. Asserted separately so nobody "harmonises" the two into one field.
test_kind_pins_the_kind_binary_not_kubernetes = lambda {
    _v = c.getDistribution("kind").vars
    assert "kind_version" in _v
    assert "k3s_k8s_version" not in _v
}

# Every distribution that ANSIBLE installs must pin something; an entry with no
# version at all is the drift this catalog exists to remove.
#
# The rancher provisioner is exempt, and not as a loophole: there the playbook
# JOINS a node into a cluster Rancher already created, so the Kubernetes version
# is Rancher's (RancherCluster.kubernetesVersion / the EnvironmentConfig) and a
# version var here would be a second place for it to drift.
test_every_ansible_distribution_pins_a_version = lambda {
    assert len([1 for _, d in c.distributions if d.provisioner == "ansible" and len([k for k, _ in d.vars if "version" in k]) == 0]) == 0
}

test_rancher_distributions_pin_no_version = lambda {
    assert len([k for k, _ in c.getDistribution("rancher-rke2").vars if "version" in k]) == 0
}

# The rancher entry earns its place with a reference run: rancher-join-test4 on
# u26-kind3, 2026-09-15 (crossplane-configurations#422).
test_rancher_rke2_is_registered = lambda {
    _d = c.getDistribution("rancher-rke2")
    assert _d.provisioner == "rancher"
    assert _d.playbooks == ["sthings.rke.rancher_register"]
    assert _d.multiNode == False
}

# The cluster is built without a CNI on purpose — Rancher's proxy needs
# cattle-cluster-agent, which needs a pod network — so the Platform owns it.
test_rancher_rke2_leaves_the_cni_to_the_platform = lambda {
    _d = c.getDistribution("rancher-rke2")
    assert _d.cniOwnership == "platform"
    assert _d.machineGlobalConfig["cni"] == "none"
    assert _d.machineGlobalConfig["disable-kube-proxy"] == True
}

# Cilium replaces both kube-proxy and the bundled ingress, and owns the Gateway
# API CRDs — rke2's own copy arrives after the CNI and at a version that pairs
# with neither cilium 1.19 nor 1.20.
test_rancher_rke2_keeps_rke2_out_of_the_network = lambda {
    _m = c.getDistribution("rancher-rke2").machineGlobalConfig
    assert _m["ingress-controller"] == "none"
    assert "rke2-traefik-crd" in _m["disable"]
    assert "rke2-gateway-api-crd" in _m["disable"]
}

# The kind default ({clusterName}-control-plane) is wrong on rke2, and with
# kubeProxyReplacement an unresolvable API address is a deadlock, not a delay.
test_rancher_rke2_cni_defaults_carry_the_api_address = lambda {
    _c = c.getDistribution("rancher-rke2").cniDefaults
    assert _c["cilium"]["k8sServiceHost"] == "127.0.0.1"
    assert _c["cilium"]["kubeProxyReplacement"] == True
    assert _c["gatewayAPI"]["enabled"] == True
    assert _c["values"]["l2announcements"]["enabled"] == True
    assert _c["values"]["hubble"]["ui"]["enabled"] == True
}

# The ansible distributions keep none of this: their CNI comes from their own
# role, and nothing composes a RancherCluster for them.
test_ansible_distributions_have_no_rancher_fields = lambda {
    assert len([1 for _, d in c.distributions if d.provisioner == "ansible" and (len(d.machineGlobalConfig) > 0 or len(d.cniDefaults) > 0)]) == 0
}

# --- profiles ---------------------------------------------------------------
test_profiles_registered = lambda {
    assert c.profileNames == ["base", "network", "observability", "security", "storage-openebs"]
}

# Every profile turns its platform ON — a profile that only sets "false" labels
# selects nothing and would read as enabled.
test_every_profile_sets_its_umbrella = lambda {
    assert all _n, p in c.profiles {
        any k, v in p.labels {
            k.endswith("-platform") and "/" not in k and v == "true"
        }
    }
}

# The two network components that cannot render on a ClusterStack are off.
test_network_profile_switches_off_what_cannot_render = lambda {
    _l = c.getProfile("network").labels
    assert _l["network-platform/cert-manager-vault-pki"] == "false"
    assert _l["network-platform/cilium-gateway-secondary"] == "false"
}

# Opt-in gates assert a Vault role can read a mount; only the stack that composes
# the role can know that. No registered profile carries one. (That the schema
# check REJECTS one is proven by a probe run in the PR — a KCL test cannot
# assert an expected failure.)
test_no_profile_carries_an_opt_in_gate = lambda {
    assert all _n, p in c.profiles {
        "security-platform/external-secrets-stores" not in p.labels and len([k for k in p.labels if k.endswith("/secrets-config")]) == 0
    }
}

test_storage_openebs_names_its_class = lambda {
    _a = c.getProfile("storage-openebs").annotations
    assert _a["observability-platform.stuttgart-things.com/storage-class"] == "openebs-hostpath"
}
