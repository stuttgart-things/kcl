# The cluster catalog registry.
#
# KCL has no file globbing, so every distribution is registered explicitly: add
# distributions/<name>.k, then one import and one entry here. Keeping it manual
# is the point — adding a distribution is a reviewable two-line diff.
#
# rke2 was absent until 2026-08-11 on the rule that an entry without a reference
# run is "a guess wearing the same clothes as a verified fact". That run has now
# happened — an AnsibleRun on the u26-kind3 machinery cluster drove
# sthings.rke.rke2_cluster against a Proxmox VM and produced a Ready
# control-plane on v1.35.1+rke2r1 with cilium up. See distributions/rke2.k for
# the run and for why its pins are not the play's defaults.
import .distributions.k3s as k3s
import .distributions.kind as kind
import .distributions.rancher_k3s as rancher_k3s
import .distributions.rancher_rke2 as rancher_rke2
import .distributions.rke2 as rke2
import profiles as pf
import sizes as sz
import schema as s

distributions: {str:s.Distribution} = {
    k3s = k3s.k3s
    kind = kind.kind
    # Rancher creates the cluster and a node joins it; the playbook above is the
    # JOIN, not an install. Reference run: rancher-join-test4, 2026-09-15.
    #
    # TWO entries, because machineGlobalConfig keys are the server's and k3s
    # and rke2 do not share them. Picking the wrong one builds a cluster that
    # looks healthy for ten minutes and never registers (#282).
    "rancher-k3s" = rancher_k3s.rancher_k3s
    "rancher-rke2" = rancher_rke2.rancher_rke2
    rke2 = rke2.rke2
}

sizes: {str:s.Size} = sz.sizeTable

profiles: {str:s.Profile} = pf.profileTable

distributionNames = sorted(distributions)
sizeNames = sorted(sizes)
profileNames = sorted(profiles)

# The per-node t-shirts an order should pick from, and the deprecated aliases
# that still resolve (0.12.0). A form or an XRD description lists tshirtNames.
tshirtNames = sorted([n for n, z in sizes if not z.aliasOf])
deprecatedSizeNames = sorted([n for n, z in sizes if z.aliasOf])

# How many all-role nodes an order may ask for: odd, so etcd keeps quorum, and
# small enough that one first-node API address (#171) is still an honest
# design. 1 is the default.
nodeCounts = [1, 3, 5]

_knownDist = ", ".join(distributionNames)
_knownSize = ", ".join(sizeNames)
_knownProfile = ", ".join(profileNames)
_knownMultiNode = ", ".join(sorted([n for n, d in distributions if d.multiNode]))

# Look up by name, failing loudly. KCL does NOT interpolate ${} inside assert
# messages — it prints the placeholder literally — so concatenate.
getDistribution = lambda name: str -> s.Distribution {
    assert name in distributions, "unknown distribution '" + name + "' — known: " + _knownDist
    distributions[name]
}

# The entry is chosen by the order; the SERVER is chosen by the RancherCluster's
# EnvironmentConfig. Nothing made the two agree, and disagreeing is not a render
# error but a cluster that looks healthy for ten minutes and never registers
# (#282). A consumer that has the environment's `distro` passes it here.
#
# Empty envDistro means "not known at this point" — an offline render, or the
# ansible path, where there is no rancher environment at all. Empty serverDistro
# is the same on the entry's side. Neither is a mismatch.
assertServerDistro = lambda name: str, envDistro: str -> bool {
    _d = getDistribution(name)
    assert _d.serverDistro == "" or envDistro == "" or _d.serverDistro == envDistro, "distribution '" + name + "' configures a " + _d.serverDistro + " server, but the rancher environment provisions " + envDistro + " — its machineGlobalConfig keys would be ignored in silence; pick the matching entry"
    True
}

getSize = lambda name: str -> s.Size {
    assert name in sizes, "unknown size '" + name + "' — known: " + _knownSize
    sizes[name]
}

# The SHAPE of a cluster: one node's size times `nodes` (0.12.0). Returns a Size
# whose masters is the node count, so a consumer keeps reading cpu/memory/disk
# per node and masters as the count -- exactly what it read from the old
# multi-node sizes, which is what makes `medium-mem` + 3 and `app-ha` render
# the same.
#
# nodes 0 means "the order did not say": a t-shirt then builds one node, and a
# deprecated alias its own masters. An alias WITH nodes is accepted only when
# the two agree -- `app-ha` + `nodes: 3` is redundant, `app-ha` + `nodes: 1`
# is a contradiction, and picking either silently would build a cluster nobody
# ordered.
getShape = lambda size: str, nodes: int -> s.Size {
    _s = getSize(size)
    assert nodes == 0 or nodes in nodeCounts, "nodes must be 1, 3 or 5 — got " + str(nodes) + " (an even count cannot hold etcd quorum)"
    assert _s.aliasOf == "" or nodes == 0 or nodes == _s.masters, "size '" + size + "' is a deprecated alias for size '" + _s.aliasOf + "' with nodes " + str(_s.masters) + " — nodes " + str(nodes) + " contradicts it; write size: " + _s.aliasOf + " and nodes: " + str(nodes)
    s.Size {
        cpu = _s.cpu
        memory = _s.memory
        disk = _s.disk
        masters = nodes if nodes > 0 else _s.masters
        workers = _s.workers
    }
}

# The kubeconfig-upload stage, shared by every distribution.
#
# A SEPARATE stage, not appended to the distribution playbooks: a completed
# Tekton PipelineRun is immutable, so folding the upload into the distribution
# run would mean re-running the whole cluster build (including `cilium install`
# against a live cluster) to redo an upload. This is option A of
# crossplane-configurations#168, decided — not an open assumption. cluster_name and the Vault path are
# supplied by the consumer, not the catalog — they are per-cluster values.
kubeconfigStage: s.Stage = s.Stage {
    playbooks = ["sthings.container.upload_kubeconfig_vault"]
    vars = {
        secret_path_kubeconfig = "kubeconfigs"
        # No-op safety net on k3s (the role already rewrote 127.0.0.1 to the VM
        # IP) and on kind (update_kubeconfig_ip did it); harmless either way.
        replace_ip = "true"
        ansible_become = "true"
        ansible_become_method = "sudo"
    }
    inventoryGroups = ["all"]
}

# Whether a Platform for a cluster of this distribution should enable its Cni
# component. Derived, never declared twice: "self" means the distribution's own
# role installed a CNI, so a second one would break the cluster.
platformCniEnabled = lambda name: str -> bool {
    getDistribution(name).cniOwnership == "platform"
}

# Reject a shape the distribution cannot actually build. A consumer calling
# this gets a readable error instead of silently provisioning one node when
# three were asked for. nodes 0 = not set by the order (see getShape).
assertShapeSupported = lambda distribution: str, size: str, nodes: int -> bool {
    _d = getDistribution(distribution)
    _s = getShape(size, nodes)
    assert _s.masters == 1 or _d.multiNode, "distribution '" + distribution + "' has no verified multi-node path in this catalog — the order asks for " + str(_s.masters) + " nodes (size '" + size + "'); only " + _knownMultiNode + " build more than one (see crossplane-configurations#170)"
    True
}

# The 0.11.x form: the size alone, as if the order set no `nodes`.
assertSizeSupported = lambda distribution: str, size: str -> bool {
    assertShapeSupported(distribution, size, 0)
}

getProfile = lambda name: str -> s.Profile {
    assert name in profiles, "unknown profile '" + name + "' — known: " + _knownProfile
    profiles[name]
}
