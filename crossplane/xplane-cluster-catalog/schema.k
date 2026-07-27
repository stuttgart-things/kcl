"""
Structural definitions for the stuttgart-things cluster catalog.

Deliberately holds STRUCTURAL facts only — how many cores a `medium` has, which
playbook installs k3s, which inventory groups its role requires, who owns the
CNI. Environment-specific VALUES (IPs, endpoints, Vault roles, credentials,
template UUIDs) are not here: they live in the per-environment EnvironmentConfig
or on the XR. Same line xplane-flux-catalog draws for apps.

The point is that the rules connecting these facts stop being prose. Today
"a k3s cluster must not get a Platform CNI, a kind cluster must" exists only as
a comment in two XR files in stuttgart-things/crossplane; here it is a field a
consumer can check.
"""

schema Size:
    """
    A t-shirt size. cpu/memory/disk are STRINGS because both VM XRDs
    (NativeProxmoxVM, NativeVsphereVM) take strings — emitting ints would fail
    schema validation on the composed resource.
    """
    cpu: str
    """vCPU count. -> vm.cpu on both providers."""

    memory: str
    """MiB. -> vm.memory (Proxmox) / vm.ram (vSphere). The rename is the
    consumer's job; the catalog states the fact once."""

    disk: str
    """GiB. -> vm.disk on both providers."""

    masters: int = 1
    """Control-plane node count. 1 = singlenode. >1 requires static addressing
    and an aggregate ready gate (crossplane-configurations#170), so a consumer
    that cannot do those must reject it rather than silently building one node."""

    workers: int = 0
    """Worker node count."""

    check:
        int(cpu) > 0, "cpu must be a positive integer string"
        int(memory) > 0, "memory must be a positive integer string (MiB)"
        int(disk) > 0, "disk must be a positive integer string (GiB)"
        masters > 0, "masters must be > 0"
        workers >= 0, "workers must be >= 0"
        masters == 1 or masters % 2 == 1, "masters must be odd — an even control-plane count cannot hold etcd quorum"

schema Distribution:
    """
    How a Kubernetes distribution is installed on an already-provisioned VM.

    This describes ONE ansible stage: the distribution install. The base-OS stage
    runs from the VM XR's own `spec.ansible`, and the kubeconfig-upload stage is
    shared across distributions (see `kubeconfigStage` in main.k) — they are
    separate Tekton PipelineRuns because a completed run is immutable, so folding
    them together would make re-doing one mean re-doing all.
    """
    playbooks: [str]
    """Ansible playbooks for the distribution install."""

    vars: {str:str}
    """varsFile entries as key/value. The consumer renders them into the
    ansible-run `key+-value` syntax; keeping them a map here means a consumer
    can override one without re-stating the set."""

    inventoryGroups: [str]
    """Inventory groups the role REQUIRES to exist, in order. Not cosmetic:
    sthings.rke.deploy_configure_rke branches on `groups['initial_master_node']`
    and `groups['additional_master_nodes']`, so a flat `all+[...]` inventory
    fails with an undefined-group error. Empty groups render as header-only INI
    sections, which ansible registers as existing-but-empty — which is what the
    role's `in groups[...]` tests need."""

    cniOwnership: str
    """Who installs the CNI:

      "self"     — the distribution's own role does it (k3s: its config writes
                   flannel-backend=none + disable-kube-proxy=true, so the role
                   MUST install cilium). A Platform for such a cluster must
                   leave cni.enabled off or it installs a second CNI.
      "platform" — the cluster comes up deliberately without one (kind), and the
                   Platform's Cni component is required.

    This is the field that turns the rule into something checkable."""

    multiNode: bool = False
    """Whether this distribution supports masters > 1 through this catalog. False
    is not a statement about the upstream distribution — it means the fleet has
    no verified multi-node path for it here yet."""

    check:
        len(playbooks) > 0, "a distribution needs at least one playbook"
        cniOwnership in ["self", "platform"], "cniOwnership must be 'self' or 'platform'"
        len(inventoryGroups) > 0, "inventoryGroups must name at least one group"

schema Stage:
    """A shared ansible stage that is not distribution-specific."""
    playbooks: [str]
    vars: {str:str}
    inventoryGroups: [str]

