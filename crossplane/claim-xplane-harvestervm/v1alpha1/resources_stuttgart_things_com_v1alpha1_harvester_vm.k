"""
This file mirrors the live `harvester-vm` CompositeResourceDefinition
(group resources.stuttgart-things.com, v1alpha1) maintained in
stuttgart-things/crossplane-configurations -> machinery/harvester-vm.

Kept in sync by hand against apis/definition.yaml. Notable points vs. the
auto-generated v1 schema this replaced:
  * adds `spec.environmentConfig` (EnvironmentConfig selector) and the optional
    `spec.ansible` provisioning block;
  * env-sourced fields (`providerConfigRef`, `volume.storageClassName`,
    `volume.namespace`, `volume.imageId`, `cloudInit.namespace`) are OPTIONAL
    and carry NO default, so leaving them unset lets the EnvironmentConfig win;
  * drops `vm.disks` (the Composition hardcodes the root/cloud-init disks) and
    the unused `volume.selector` / `volume.dataSource` blocks.
"""

import ..k8s.apimachinery.pkg.apis.meta.v1

schema HarvesterVM:
    r"""
    HarvesterVM is a namespaced composite resource (Crossplane v2) for managing
    Harvester / KubeVirt virtual machines.

    Attributes
    ----------
    apiVersion : str, default is "resources.stuttgart-things.com/v1alpha1", required
        APIVersion defines the versioned schema of this representation of an object.
    kind : str, default is "HarvesterVM", required
        Kind is a string value representing the REST resource this object represents.
    metadata : v1.ObjectMeta, default is Undefined, optional
        metadata
    spec : ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec, default is Undefined, required
        spec
    status : ResourcesStuttgartThingsComV1alpha1HarvesterVMStatus, default is Undefined, optional
        status
    """
    apiVersion: "resources.stuttgart-things.com/v1alpha1" = "resources.stuttgart-things.com/v1alpha1"

    kind: "HarvesterVM" = "HarvesterVM"

    metadata?: v1.ObjectMeta
    spec: ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec

    status?: ResourcesStuttgartThingsComV1alpha1HarvesterVMStatus

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec:
    r"""
    HarvesterVM spec

    Attributes
    ----------
    environmentConfig : str, default is "default", optional
        Selects the Crossplane EnvironmentConfig that supplies shared
        per-environment infrastructure defaults (providerConfigRef,
        storageClassName, namespace, networkName, imageId).
    providerConfigRef : str, default is Undefined, optional
        Name of the provider-kubernetes ClusterProviderConfig. Defaults from the
        EnvironmentConfig (`providerConfigRef`) when unset.
    volume : ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume, default is Undefined, required
        Volume (root disk PVC) configuration
    cloudInit : ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit, default is Undefined, required
        Cloud-Init configuration
    vm : ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVm, default is Undefined, required
        VirtualMachine configuration
    ansible : ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecAnsible, default is Undefined, optional
        Optional Ansible base-OS provisioning (opt-in)
    """
    environmentConfig?: str = "default"
    providerConfigRef?: str
    volume: ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume

    cloudInit: ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit

    vm: ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVm

    ansible?: ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecAnsible

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume:
    r"""
    Volume (root disk PVC) configuration for Harvester VM.

    `storageClassName`, `namespace` and `imageId` are env-sourced: leave them
    unset to inherit from the EnvironmentConfig.

    Attributes
    ----------
    pvcName : str, default is Undefined, required
        Name of the PVC
    storageClassName : str, default is Undefined, optional
        Storage class name. Defaults from the EnvironmentConfig when unset.
    namespace : str, default is Undefined, optional
        Namespace for the PVC. Defaults from the EnvironmentConfig when unset.
    imageId : str, default is Undefined, optional
        Harvester image id, rendered into the PVC annotation
        `harvesterhci.io/imageId`. Defaults from the EnvironmentConfig when unset.
    storage : str, default is "10Gi", optional
        Storage size
    accessModes : [str], default is ["ReadWriteOnce"], optional
        Access modes for the PVC
    volumeMode : str, default is "Filesystem", optional
        Volume mode (Filesystem or Block)
    annotations : {str:str}, default is Undefined, optional
        Annotations for the PVC
    labels : {str:str}, default is Undefined, optional
        Labels for the PVC
    """
    pvcName: str

    storageClassName?: str
    namespace?: str
    imageId?: str
    storage?: str = "10Gi"
    accessModes?: [str] = ["ReadWriteOnce"]
    volumeMode?: str = "Filesystem"
    annotations?: {str:str}
    labels?: {str:str}

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit:
    r"""
    Cloud-Init configuration for Harvester VM.

    `namespace` is env-sourced: leave it unset to inherit from the
    EnvironmentConfig.

    Attributes
    ----------
    vmName : str, default is Undefined, required
        Name of the VM for cloud-init (used for the Secret name)
    hostname : str, default is Undefined, required
        Hostname of the VM
    namespace : str, default is Undefined, optional
        Namespace for cloud-init secret. Defaults from the EnvironmentConfig when unset.
    domain : str, default is "local", optional
        Domain name
    timezone : str, default is Undefined, optional
        Timezone (e.g., Europe/Berlin)
    users : [ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser], default is Undefined, optional
        List of users to create
    packages : [str], default is ["qemu-guest-agent"], optional
        Packages to install. Keep `qemu-guest-agent` so the VMI reports its IP.
    writeFiles : [ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitWriteFile], default is Undefined, optional
        Files to write
    runcmd : [str], default is Undefined, optional
        Commands to run
    bootcmd : [str], default is Undefined, optional
        Boot commands
    packageUpdate : bool, default is True, optional
        Update packages on boot
    packageUpgrade : bool, default is False, optional
        Upgrade packages on boot
    sshPasswordAuth : bool, default is False, optional
        Enable SSH password authentication
    disableRoot : bool, default is True, optional
        Disable root login
    networkConfig : str, default is Undefined, optional
        Network configuration (cloud-init network-config format)
    """
    vmName: str

    hostname: str

    namespace?: str
    domain?: str = "local"
    timezone?: str
    users?: [ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser]
    packages?: [str] = ["qemu-guest-agent"]
    writeFiles?: [ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitWriteFile]
    runcmd?: [str]
    bootcmd?: [str]
    packageUpdate?: bool = True
    packageUpgrade?: bool = False
    sshPasswordAuth?: bool = False
    disableRoot?: bool = True
    networkConfig?: str

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser:
    r"""
    User configuration for cloud-init

    Attributes
    ----------
    name : str, default is Undefined, optional
        Username
    sshAuthorizedKeys : [str], default is Undefined, optional
        SSH authorized keys
    sudo : str, default is Undefined, optional
        Sudo configuration
    groups : str, default is Undefined, optional
        Groups for the user
    shell : str, default is Undefined, optional
        Login shell
    password : str, default is Undefined, optional
        Password (hashed)
    lockPasswd : bool, default is Undefined, optional
        Lock password
    """
    name?: str
    sshAuthorizedKeys?: [str]
    sudo?: str
    groups?: str
    shell?: str
    password?: str
    lockPasswd?: bool

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitWriteFile:
    r"""
    Write file configuration for cloud-init

    Attributes
    ----------
    path : str, default is Undefined, optional
        File path
    content : str, default is Undefined, optional
        File content
    owner : str, default is Undefined, optional
        File owner
    permissions : str, default is Undefined, optional
        File permissions
    encoding : str, default is Undefined, optional
        Content encoding
    """
    path?: str
    content?: str
    owner?: str
    permissions?: str
    encoding?: str

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVm:
    r"""
    VirtualMachine (KubeVirt/Harvester) configuration.

    The root and cloud-init disks are managed by the Composition, so there is
    no `disks` field here.

    Attributes
    ----------
    description : str, default is Undefined, optional
        VM description
    runStrategy : str, default is "RerunOnFailure", optional
        Run strategy (Always, RerunOnFailure, Manual, Halted)
    evictionStrategy : str, default is "LiveMigrateIfPossible", optional
        Eviction strategy
    terminationGracePeriodSeconds : int, default is 120, optional
        Termination grace period
    os : str, default is "ubuntu", optional
        Operating system type
    machineType : str, default is "q35", optional
        Machine type
    cpu : ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmCpu, default is Undefined, required
        CPU configuration
    resources : ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources, default is Undefined, required
        Resource requests/limits
    networks : [ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmNetwork], default is Undefined, optional
        Multus networks. When omitted, a single `default` interface attaches to
        the EnvironmentConfig `networkName`.
    """
    description?: str
    runStrategy?: str = "RerunOnFailure"
    evictionStrategy?: str = "LiveMigrateIfPossible"
    terminationGracePeriodSeconds?: int = 120
    os?: str = "ubuntu"
    machineType?: str = "q35"
    cpu: ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmCpu

    resources: ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources

    networks?: [ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmNetwork]

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmCpu:
    r"""
    CPU configuration

    Attributes
    ----------
    cores : int, default is Undefined, required
        Number of CPU cores
    sockets : int, default is 1, optional
        Number of CPU sockets
    threads : int, default is 1, optional
        Number of threads per core
    """
    cores: int

    sockets?: int = 1
    threads?: int = 1

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources:
    r"""
    Resource requests/limits

    Attributes
    ----------
    memory : str, default is Undefined, required
        Memory (e.g., 8Gi)
    cpu : str, default is Undefined, required
        CPU (e.g., "4")
    """
    memory: str

    cpu: str

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmNetwork:
    r"""
    Network configuration

    Attributes
    ----------
    name : str, default is Undefined, required
        Network interface name
    networkName : str, default is Undefined, required
        Network name (namespace/name format)
    """
    name: str

    networkName: str

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecAnsible:
    r"""
    Optional Ansible base-OS provisioning, run after the VM is up and the QEMU
    guest agent has reported an IP. Disabled by default.

    Attributes
    ----------
    enabled : bool, default is False, optional
        Enable Ansible provisioning after VM creation.
    pipelineNamespace : str, default is "tekton-ci", optional
        Namespace for the Tekton PipelineRun.
    ansibleWorkingImage : str, default is Undefined, optional
        Ansible working container image.
    credentialsSecretName : str, default is "ansible-credentials", optional
        Secret holding Ansible credentials.
    gitRepoUrl : str, default is Undefined, optional
        Git repository URL for the pipeline.
    playbooks : [str], default is Undefined, optional
        Ansible playbooks to run.
    varsFile : [str], default is Undefined, optional
        Ansible vars (`key+-value` form).
    varsInventory : [str], default is Undefined, optional
        Ansible inventory entries. Auto-populated with the VM IP when omitted.
    extraCollections : [str], default is Undefined, optional
        Extra Ansible collections to install.
    extraRoles : [str], default is Undefined, optional
        Extra Ansible roles to install.
    crossplaneProviderConfig : str, default is "in-cluster", optional
        provider-kubernetes config used to wrap the PipelineRun.
    wrapInCrossplane : bool, default is True, optional
        Wrap the PipelineRun in a Crossplane Object.
    """
    enabled?: bool = False
    pipelineNamespace?: str = "tekton-ci"
    ansibleWorkingImage?: str
    credentialsSecretName?: str = "ansible-credentials"
    gitRepoUrl?: str
    playbooks?: [str]
    varsFile?: [str]
    varsInventory?: [str]
    extraCollections?: [str]
    extraRoles?: [str]
    crossplaneProviderConfig?: str = "in-cluster"
    wrapInCrossplane?: bool = True

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMStatus:
    r"""
    HarvesterVM status

    Attributes
    ----------
    volume : ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusVolume, default is Undefined, optional
        Volume status
    cloudInit : ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusCloudInit, default is Undefined, optional
        CloudInit status
    vm : ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusVm, default is Undefined, optional
        VM status
    share : {str:any}, default is Undefined, optional
        Freeform status surface. `share.ip` holds the VM IP(s) reported by the
        QEMU guest agent.
    ansibleReady : bool, default is Undefined, optional
        Whether Ansible provisioning has completed (true when Ansible disabled).
    """
    volume?: ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusVolume
    cloudInit?: ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusCloudInit
    vm?: ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusVm
    share?: {str:any}
    ansibleReady?: bool

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusVolume:
    r"""
    Volume status

    Attributes
    ----------
    pvcName : str, default is Undefined, optional
        PVC name
    ready : bool, default is Undefined, optional
        Ready state
    """
    pvcName?: str
    ready?: bool

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusCloudInit:
    r"""
    CloudInit status

    Attributes
    ----------
    secretName : str, default is Undefined, optional
        Secret name
    ready : bool, default is Undefined, optional
        Ready state
    """
    secretName?: str
    ready?: bool

schema ResourcesStuttgartThingsComV1alpha1HarvesterVMStatusVm:
    r"""
    VM status

    Attributes
    ----------
    name : str, default is Undefined, optional
        VM name
    ready : bool, default is Undefined, optional
        Ready state
    """
    name?: str
    ready?: bool

