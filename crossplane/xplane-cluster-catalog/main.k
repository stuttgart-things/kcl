# The cluster catalog registry.
#
# KCL has no file globbing, so every distribution is registered explicitly: add
# distributions/<name>.k, then one import and one entry here. Keeping it manual
# is the point — adding a distribution is a reviewable two-line diff.
#
# rke2 is DELIBERATELY ABSENT. The fleet runs multinode rke2 clusters through
# ansible (exec/labul/sthings-infra-rke2), but no Crossplane path has ever built
# one, so an entry here would be a guess wearing the same clothes as a verified
# fact. Add it after a reference run, not before.
import .distributions.k3s as k3s
import .distributions.kind as kind
import sizes as sz
import schema as s

distributions: {str:s.Distribution} = {
    k3s = k3s.k3s
    kind = kind.kind
}

sizes: {str:s.Size} = sz.sizeTable

distributionNames = sorted(distributions)
sizeNames = sorted(sizes)

_knownDist = ", ".join(distributionNames)
_knownSize = ", ".join(sizeNames)

# Look up by name, failing loudly. KCL does NOT interpolate ${} inside assert
# messages — it prints the placeholder literally — so concatenate.
getDistribution = lambda name: str -> s.Distribution {
    assert name in distributions, "unknown distribution '" + name + "' — known: " + _knownDist
    distributions[name]
}

getSize = lambda name: str -> s.Size {
    assert name in sizes, "unknown size '" + name + "' — known: " + _knownSize
    sizes[name]
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

# Reject a size the distribution cannot actually build. A consumer calling this
# gets a readable error instead of silently provisioning one node when three
# were asked for.
assertSizeSupported = lambda distribution: str, size: str -> bool {
    _d = getDistribution(distribution)
    _s = getSize(size)
    assert _s.masters == 1 or _d.multiNode, "distribution '" + distribution + "' has no verified multi-node path in this catalog — size '" + size + "' asks for " + str(_s.masters) + " masters (see crossplane-configurations#170)"
    True
}
