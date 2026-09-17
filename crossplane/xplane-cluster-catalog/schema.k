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

import regex

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

    clusterNameVars: [str] = []
    """Extra varsFile keys that must carry the CLUSTER NAME, on top of the
    `cluster_name` every stage already gets.

    `cluster_name` is not a universal handle: `sthings.container.kind` never
    reads it — it names the cluster from `kind_cluster_name` and otherwise falls
    back to its own play default, `dev`. So a ClusterStack asking for
    `kindstack-test` built a kind cluster called `dev`, and the Cni child's
    `k8sServiceHost` (`<clusterName>-control-plane`) pointed at a container that
    does not exist. With `kubeProxyReplacement: true` that is a deadlock, not a
    slow failure: cilium cannot reach the API through the 10.96.0.1 VIP either,
    because nothing programs that VIP until cilium is up
    (crossplane-configurations#232).

    A LIST, and applied to EVERY stage, because the same name is read by more
    than one play: `sthings.container.upload_kubeconfig_vault` derives
    `kubeconfig_path` from `kind_cluster_name` too. Before this field both sides
    independently defaulted to `dev` and therefore agreed by accident — setting
    the name in the distribution stage alone would break that agreement and the
    upload would fetch a path that does not exist."""

    provisioner: str = "ansible"
    """WHO creates the cluster, which decides what `playbooks` above even means:

      "ansible" — the playbooks install the distribution on an
                  already-provisioned VM. The two stages a consumer runs are
                  the distribution install and the kubeconfig upload.
      "rancher" — Rancher creates the cluster; the playbooks JOIN a node into
                  it and publish that node's kubeconfig. A consumer must
                  compose a RancherCluster XR, wait for the node-registration
                  Secret it publishes, and run this one stage instead of the
                  distribution + kubeconfig pair.

    The distinction is not cosmetic: on the rancher path the cluster exists
    before any node does, and everything downstream (kubeconfig, CNI, Argo CD)
    hangs off a cluster whose API server is not reachable through Rancher until
    a CNI runs — see crossplane-configurations#422."""

    machineGlobalConfig: {str:any} = {}
    """`rkeConfig.machineGlobalConfig` for the provisioning Cluster — the
    distribution's own config file. Only meaningful with provisioner
    "rancher"; a consumer passes it to the RancherCluster XR."""

    cniDefaults: {str:any} = {}
    """Defaults for the Platform's `Cni` child: the cluster-shape facts a CNI on
    THIS distribution needs, as `{cilium, gatewayAPI, values}`. A consumer merges
    them UNDER the XR's own `platform.cni`, so a caller can still override one
    key. Only meaningful where cniOwnership is "platform" — where the
    distribution installs its own CNI there is nothing to default."""

    check:
        len(playbooks) > 0, "a distribution needs at least one playbook"
        cniOwnership in ["self", "platform"], "cniOwnership must be 'self' or 'platform'"
        len(inventoryGroups) > 0, "inventoryGroups must name at least one group"
        provisioner in ["ansible", "rancher"], "provisioner must be 'ansible' or 'rancher'"
        provisioner == "rancher" or len(machineGlobalConfig) == 0, "machineGlobalConfig belongs to the rancher provisioner — the ansible path configures the distribution through vars"
        cniOwnership == "platform" or len(cniDefaults) == 0, "cniDefaults only apply where the Platform owns the CNI"

schema Stage:
    """A shared ansible stage that is not distribution-specific."""
    playbooks: [str]
    vars: {str:str}
    inventoryGroups: [str]

schema Profile:
    """
    A named set of Argo CD cluster labels (and annotation defaults) selecting an
    app platform — decision 6.2 in crossplane-configurations#438.

    Structural, like the rest of this catalog: WHICH platform a profile turns on
    and which components cannot work on a cluster built this way. Nothing here is
    environment-specific — no URLs, no Vault addresses.

    The platform ApplicationSets are OPT-OUT: the umbrella label turns every
    component on unless it says "false". So a profile is mostly the umbrella plus
    the components that would fail on a single-reservation, Platform-issued
    cluster. The OPT-IN gates (`…/secrets-config`,
    `security-platform/external-secrets-stores`) are deliberately NOT allowed
    here: they assert that a Vault role can read a mount, which only the stack
    that composes the role can know — so xplane-cluster derives them.
    """
    labels: {str:str}
    """Cluster Secret labels. Values are "true"/"false" strings, exactly as the
    ApplicationSet selectors compare them."""

    annotations: {str:str} = {}
    """Annotation defaults a platform needs and that follow from the profile
    itself (e.g. the StorageClass openebs provides)."""

    appSecrets: [str] = []
    """AppSecretProfile names (secrets.stuttgart-things.com, cluster-scoped) the
    workloads this profile deploys need — crossplane-configurations#464.

    A LIST, not the profile's own name: one ApplicationSet can ship several apps
    (tabletennis-platform deploys schmetterpause, zaehlwerk and the
    light-catcher), and each app declares its own secrets. Listing a name here
    makes a missing AppSecretProfile a render error in xplane-cluster instead of
    a cluster whose ExternalSecrets silently find nothing."""

    check:
        len([v for _k, v in labels if v not in ["true", "false"]]) == 0, "profile label values must be the strings \"true\" or \"false\""
        len([k for k in labels if k.endswith("/secrets-config") or k == "security-platform/external-secrets-stores"]) == 0, "opt-in gates (…/secrets-config, security-platform/external-secrets-stores) are derived by the stack, never set by a profile"
        len([n for i, n in appSecrets if n in appSecrets[:i:]]) == 0, "appSecrets lists a name twice"
        all n in appSecrets {
            regex.match(n, "^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")
        }, "appSecrets entries are AppSecretProfile names: lowercase letters, digits and dashes"

