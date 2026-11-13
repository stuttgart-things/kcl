"""
NativeVsphereVM / NativeProxmoxVM orders (resources.stuttgart-things.com/v1alpha1)
for the native VM compositions (crossplane-configurations vsphere-vm /
proxmox-vm).

Renders the same order as the Backstage template create-vm
(stuttgart-things/stuttgart-things backstage/templates/create-vm) for every
lab x use case: hack/check-vm-kcl.py there compares both for the snapshots in
hack/testdata/create-vm and the built orders (stuttgart-things#4295).

Output: a YAML stream.
  1. the XR                                   -> the order file (source-path)
  2. dev only: EnvironmentConfig dev-machine-* -> the same order file
  3. dev only: ScrapeConfig host-*             -> its own file, named by the
     annotation stuttgart-things.com/target-path (sthings-infra monitoring)

Lab (templateName, or lab)
--------------------------
labda-vsphere : NativeVsphereVM, EnvironmentConfig labda, factory machinery
labul-proxmox : NativeProxmoxVM, EnvironmentConfig labul, factory machinery-labul
"""

import manifests
import v1alpha1 as xr

_params = option("params") or {}
_spec = _params?.vm?.spec or {}

# ---- input helpers ----------------------------------------------------------
# A value counts as set unless it is missing, None or "". 0, False and [] are
# set: kind_workers=0 and dev_features=[] mean something.
_isSet = lambda v -> bool {
    v != None and v != Undefined and v != ""
}

# The first set value of spec, -D option and params.
_raw = lambda k: str -> any {
    _a = _spec?[k]
    _b = option(k)
    _c = _params?[k]
    _a if _isSet(_a) else (_b if _isSet(_b) else _c)
}

# A string input; `fallback` when unset. -D turns 3 into an int and true into
# a bool, so everything goes through str().
_str = lambda k: str, fallback: str -> str {
    _v = _raw(k)
    str(_v) if _isSet(_v) else fallback
}

# The first set input of two names (form name first, old camelCase alias
# second).
_str2 = lambda k: str, alias: str, fallback: str -> str {
    _str(k, _str(alias, fallback))
}

# A bool input: real bools, or "true"/"1"/"yes" in any case.
_bool = lambda k: str, fallback: bool -> bool {
    _v = _raw(k)
    (str(_v).lower() in ["true", "1", "yes"]) if _isSet(_v) else fallback
}

# A list input: a real list, or a comma-separated string. None when unset, so
# that "unset" (take the default) and [] (nothing ticked) differ.
_list = lambda k: str -> any {
    _v = _raw(k)
    ([str(x) for x in _v] if typeof(_v) == "list" else [s.strip() for s in str(_v).split(",") if s.strip() != ""]) if _isSet(_v) else None
}

# ---- what is ordered --------------------------------------------------------
_lab = _str2("lab", "templateName", "labul-proxmox")
assert _lab in ["labda-vsphere", "labul-proxmox"], "lab must be labda-vsphere or labul-proxmox, got ${_lab}"
_vsphere = _lab == "labda-vsphere"
_labShort = "labda" if _vsphere else "labul"

_useCase = _str("use_case", "baseos")
assert _useCase in ["baseos", "kind", "dev", "rke2", "github-runner"], "use_case must be baseos, kind, dev, rke2 or github-runner, got ${_useCase}"

# OS of the VM (stuttgart-things#4489). A key of the vspherevm EnvironmentConfig's
# `templates` table, which supplies templateUuid AND guestId (vspherevm >=
# v0.15.0) -- the order never names a UUID. Only LabDA vSphere offers a second
# OS, and only for baseos: the other use cases' plays assume apt (Ubuntu).
# ubuntu26 is the environment's default template, so it is NOT written into the
# order: an order without os renders byte-identical to before.
_os = _str("os", "ubuntu26")
assert _os in ["ubuntu26", "rocky10"], "os must be ubuntu26 or rocky10, got ${_os}"
assert _os == "ubuntu26" or _vsphere, "os ${_os} is only offered for labda-vsphere"
assert _os == "ubuntu26" or _useCase == "baseos", "os ${_os} is only offered for use_case baseos, got ${_useCase}"

# Same t-shirt sizes as create-vm.
_sizes = {
    small = {cpu = "2", memory = "4096", disk = "40"}
    medium = {cpu = "4", memory = "8192", disk = "64"}
    large = {cpu = "8", memory = "16384", disk = "100"}
    xlarge = {cpu = "16", memory = "24576", disk = "200"}
}
_sizeName = _str("size", "medium")
assert _sizeName in _sizes, "size must be one of small, medium, large, xlarge, got ${_sizeName}"
# The form narrows the size per use case; here it is a rule, not a widget.
assert _useCase not in ["dev", "github-runner"] or _sizeName in ["large", "xlarge"], "use_case ${_useCase} needs size large or xlarge, got ${_sizeName}"
assert _useCase != "rke2" or _sizeName != "small", "use_case rke2 needs size medium or larger"
_size = _sizes[_sizeName]

_name = _str("name", "demo")
# Explicit values beat the size.
_cpu = _str("cpu", _size.cpu)
_memory = _str("memory", _size.memory)
_disk = _str("disk", _size.disk)

# ---- placement (stuttgart-things#4296) --------------------------------------
# Today's values are the defaults: each lab builds its own VMs
# (stuttgart-things#3715, #4310). An order service fills these after its
# placement step.
_factories = {
    "labul-proxmox" = {cluster = "machinery-labul", lab = "labul", orders = "clusters/labul/proxmox/machinery-labul-orders-xrs"}
    "labda-vsphere" = {cluster = "machinery", lab = "labda", orders = "clusters/labda/vsphere/machinery-orders-xrs"}
}
_factory = _factories[_lab]
_managementCluster = _str2("management_cluster", "managementCluster", _factory.cluster)
_managementLab = _str("management_lab", _factory.lab)
_sourcePath = _str("source_path", "${_factory.orders}/${_name}.yaml")
_environmentConfig = _str2("environment_config", "environmentConfig", _labShort)
_claimNamespace = _str2("claim_namespace", "claimNamespace", "default")
_monitoringPath = _str("monitoring_path", "clusters/labda/vsphere/sthings-infra/monitoring/host-${_name}.yaml")

# Who ordered, for whom, and the order (#4276, #4296).
_requestedBy = _str("requested_by", "")
_owner = _str("owner", _requestedBy)
_orderId = _str("order_id", "")
# The intake that built the VM, shown on its login banner (#3439).
_buildSource = _str("build_source", "claim-machinery")

_orderAnnotations = {"stuttgart-things.com/order-id" = _orderId} if _orderId else {}

# ---- use case inputs --------------------------------------------------------
_kindWorkers = _str("kind_workers", "1")

_allDevFeatures = ["toolchain", "docker", "go", "kind", "ansible", "pre-commit", "semantic-release", "nerdctl", "podman", "claude-code", "shell", "vhs", "dotfiles"]
_devFeaturesIn = _list("dev_features")
_f = _devFeaturesIn if _devFeaturesIn != None else _allDevFeatures
_docker = "docker" in _f or "kind" in _f
_devGoVersion = _str("dev_go_version", "1.27.4")
_devKindWorkers = _str("dev_kind_workers", "3")
_devKindName = _str("dev_kind_name", "dev")

_runnerLabels = _str("runner_labels", "")
_runnerCount = int(_str("runner_count", "1"))
_runnerToolchain = _bool("runner_toolchain", True)

# ---- playbooks --------------------------------------------------------------
# dev: sthings.baseos.dev's imports, in its order, only the ticked ones;
# node_exporter always last (#3510).
_devPlays = [
    *(["sthings.baseos.binaries"] if "toolchain" in _f else [])
    *(["sthings.baseos.ansible"] if "ansible" in _f else [])
    *(["sthings.baseos.golang"] if "go" in _f else [])
    *(["sthings.baseos.pre_commit"] if "pre-commit" in _f else [])
    *(["sthings.baseos.semantic_release"] if "semantic-release" in _f else [])
    *(["sthings.container.docker"] if _docker else [])
    *(["sthings.container.tools"] if "toolchain" in _f else [])
    *(["sthings.container.nerdctl"] if "nerdctl" in _f else [])
    *(["sthings.container.podman"] if "podman" in _f else [])
    *(["sthings.baseos.vhs"] if "vhs" in _f else [])
    # A container runtime was installed: reboot before the user plays.
    *(["sthings.baseos.reboot_vm"] if _docker or "nerdctl" in _f or "podman" in _f else [])
    *(["sthings.baseos.claude_code"] if "claude-code" in _f else [])
    *(["sthings.baseos.starship", "sthings.baseos.tmux", "sthings.baseos.shell_tools"] if "shell" in _f else [])
    *(["sthings.baseos.dotfiles"] if "dotfiles" in _f else [])
    *(["sthings.baseos.dev_config"] if _docker or "nerdctl" in _f else [])
    *(["sthings.container.kind"] if "kind" in _f else [])
    "sthings.baseos.node_exporter"
]

_useCasePlays = {
    baseos = []
    kind = ["sthings.container.kind"]
    dev = _devPlays
    rke2 = ["sthings.rke.rke2_cluster"]
    "github-runner" = [
        *(["sthings.baseos.binaries", "sthings.container.tools"] if _runnerToolchain else [])
        "sthings.baseos.gh_runner"
    ]
}
_playbooks = ["sthings.baseos.setup", *_useCasePlays[_useCase]]

# ---- varsFile ---------------------------------------------------------------
_baseVars = [
    "manage_filesystem+-true"
    "update_packages+-true"
    "vm_hostname+-${_name}"
    # Build marker: sthings.baseos.setup writes these to /etc/sthings/build.yaml
    # (stuttgart-things#3439).
    "sthings_build_source+-${_buildSource}"
    "sthings_build_order+-${_name}-vm"
    "sthings_build_use_case+-${_useCase}"
    "sthings_build_lab+-${_labShort}"
    "sthings_build_management_cluster+-${_managementCluster}"
    "sthings_build_method+-crossplane"
    "sthings_build_management_lab+-${_managementLab}"
]

_kindVars = lambda clusterName: str, workers: str -> [str] {
    [
        "kind_cluster_name+-${clusterName}"
        "install_kind+-true"
        "create_kind_cluster+-true"
        "count_controlplane_nodes+-1"
        "count_worker_nodes+-${workers}"
        "rebuild_kind_cluster+-false"
        "enable_ingress_ports+-true"
        "update_kubeconfig_ip+-true"
        "fetch_kubeconfig+-false"
        "disableDefaultCNI+-false"
        "kubeProxyMode+-iptables"
    ]
}

_runnerInstances = ", ".join(['{"name": "${_name}-${i}"}' for i in range(1, _runnerCount + 1)])

_useCaseVars = {
    baseos = []
    kind = ["ansible_user+-sthings", *_kindVars(_name, _kindWorkers)]
    dev = [
        "ansible_user+-sthings"
        # LVM split for a developer machine (#3439).
        "lvm_root_sizing+-20%"
        "lvm_home_sizing+-40%"
        *(["golang_version+-${_devGoVersion}"] if "go" in _f else [])
        *(_kindVars(_devKindName, _devKindWorkers) if "kind" in _f else [])
    ]
    rke2 = [
        "rke_state+-present"
        "rke2_k8s_version+-1.35.1"
        "rke2_release_kind+-rke2r1"
        "cluster_setup+-singlenode"
        "rke2_cni+-none"
        "install_cilium+-true"
        "disableKubeProxy+-true"
        "rke2_airgapped_installation+-true"
        "prepare_rancher_ha_nodes+-true"
        "install_helm_diff+-false"
        "cluster_name+-${_name}"
        "fetched_kubeconfig_path+-/tmp/kubeconfig"
        "ansible_become+-true"
        "ansible_become_method+-sudo"
    ]
    "github-runner" = [
        "github_owner+-stuttgart-things"
        "runner_scope+-org"
        "runner_labels+-self-hosted,Linux,X64,${_runnerLabels}"
        "runner_instances+-[${_runnerInstances}]"
        "docker_users+-[sthings, gh-runner]"
        "runner_force_reconfigure+-false"
    ]
}

# ---- the XR -----------------------------------------------------------------
# The VM's own AnsibleRun, emitted once the VM has an IP. No extraCollections:
# a list here REPLACES ansible-run-defaults instead of adding to it.
_ansible = {
    enabled = True
    pipelineNamespace = "tekton-ci"
    crossplaneProviderConfig = "in-cluster"
    if _useCase == "github-runner":
        # pragma: allowlist nextline secret
        extraEnvSecretName = "github-runner-token"
    if _useCase == "dev" and "dotfiles" in _f:
        # pragma: allowlist nextline secret
        vaultSecretName = "vault-devvm-dotfiles-reader"
    playbooks = _playbooks
    if _useCase == "rke2":
        inventoryGroups = ["initial_master_node", "additional_master_nodes", "workers"]
    varsFile = [*_baseVars, *_useCaseVars[_useCase]]
} if _bool("ansible", True) else {enabled = False}

_metadata = {
    name = "${_name}-vm"
    namespace = _claimNamespace
    if _orderId:
        labels = {"stuttgart-things.com/order-id" = _orderId}
    annotations = {
        "stuttgart-things.com/management-cluster" = _managementCluster
        # The file this XR lives in: deleting removes the file first.
        "stuttgart-things.com/source-path" = _sourcePath
        if _requestedBy:
            "stuttgart-things.com/requested-by" = _requestedBy
            "stuttgart-things.com/owner" = _owner
        # The orders do not prune: deleting is file first, then the XR.
        "kustomize.toolkit.fluxcd.io/prune" = "disabled"
        **_orderAnnotations
    }
}

# vSphere: ram, no agentEnabled, no cloudInit. Proxmox: memory. The
# compositions prune the wrong keys silently instead of failing.
_xrVsphere = {
    apiVersion = "resources.stuttgart-things.com/v1alpha1"
    kind = "NativeVsphereVM"
    metadata = _metadata
    spec = {
        environmentConfig = _environmentConfig
        vm = {
            name = _name
            cpu = _cpu
            ram = _memory
            disk = _disk
            if _os != "ubuntu26":
                os = _os
            tagsPolicy = "Merge"
        }
        ansible = _ansible
    }
}

_xrProxmox = {
    apiVersion = "resources.stuttgart-things.com/v1alpha1"
    kind = "NativeProxmoxVM"
    metadata = _metadata
    spec = {
        environmentConfig = _environmentConfig
        vm = {name = _name, cpu = _cpu, memory = _memory, disk = _disk, agentEnabled = True, tagsPolicy = "Merge"}
        cloudInit = {ipv4Address = "dhcp"}
        ansible = _ansible
    }
}

# Type check against the XRD schemas; the plain dict is what is emitted, so the
# schemas' defaults do not leak into the order.
if _vsphere:
    _typedVsphere = xr.NativeVsphereVM {**_xrVsphere}
else:
    _typedProxmox = xr.NativeProxmoxVM {**_xrProxmox}
_xr = _xrVsphere if _vsphere else _xrProxmox

# ---- dev only ---------------------------------------------------------------
_fqdn = "${_name}.tiab.labda.sva.de" if _vsphere else "${_name}.labul.sva.de"

# The VM on the nightly dev-maintenance list (#3439).
_devMachine = {
    apiVersion = "apiextensions.crossplane.io/v1beta1"
    kind = "EnvironmentConfig"
    metadata = {
        name = "dev-machine-${_name}"
        labels = {"stuttgart-things.com/dev-machine" = "true"}
        annotations = {
            "kustomize.toolkit.fluxcd.io/prune" = "disabled"
            **_orderAnnotations
        }
    }
    data = {
        host = _fqdn
        lab = _labShort
    }
}

# Host monitoring: the central Prometheus on sthings-infra scrapes the
# node_exporter the last play installs (#3510). Its own file: the client
# writes it to the target-path.
_scrapeConfig = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind = "ScrapeConfig"
    metadata = {
        name = "host-${_name}"
        namespace = "monitoring"
        labels = {release = "kube-prometheus-stack"}
        annotations = {
            "stuttgart-things.com/target-path" = _monitoringPath
            **_orderAnnotations
        }
    }
    spec = {
        jobName = "host-exporters"
        scrapeInterval = "30s"
        scrapeTimeout = "10s"
        staticConfigs = [{
            labels = {role = "dev", lab = _labShort, host = _fqdn}
            targets = ["${_fqdn}:9100"]
        }]
    }
}

_docs = [_xr, *([_devMachine, _scrapeConfig] if _useCase == "dev" else [])]
manifests.yaml_stream(_docs)
