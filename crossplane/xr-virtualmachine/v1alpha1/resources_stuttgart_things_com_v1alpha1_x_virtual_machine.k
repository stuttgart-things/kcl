"""
This file describes the XVirtualMachine XR (resources.stuttgart-things.com/v1alpha1).
It mirrors the CompositeResourceDefinition in
crossplane-configurations/machinery/virtual-machine/apis/definition.yaml.
"""
import ..k8s.apimachinery.pkg.apis.meta.v1


schema XVirtualMachine:
    r"""
    resources stuttgart things com v1alpha1 x virtual machine

    Attributes
    ----------
    apiVersion : str, default is "resources.stuttgart-things.com/v1alpha1", required
        APIVersion defines the versioned schema of this representation of an object.
    kind : str, default is "XVirtualMachine", required
        Kind is a string value representing the REST resource this object represents.
    metadata : v1.ObjectMeta, default is Undefined, optional
        metadata
    spec : ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpec, default is Undefined, required
        spec
    status : ResourcesStuttgartThingsComV1alpha1XVirtualMachineStatus, default is Undefined, optional
        status
    """


    apiVersion: "resources.stuttgart-things.com/v1alpha1" = "resources.stuttgart-things.com/v1alpha1"

    kind: "XVirtualMachine" = "XVirtualMachine"

    metadata?: v1.ObjectMeta

    spec: ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpec

    status?: ResourcesStuttgartThingsComV1alpha1XVirtualMachineStatus


schema ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpec:
    r"""
    resources stuttgart things com v1alpha1 x virtual machine spec

    Attributes
    ----------
    size : str, default is Undefined, required
        T-shirt size for the VM (maps to cpu/ram/disk). One of small, medium, large, xlarge.
    provider : str, default is Undefined, required
        Infrastructure provider. vsphere/proxmox emit a VMProvision (OpenTofu
        Workspace); harvester emits a HarvesterVM (KubeVirt) directly.
    environment : str, default is Undefined, required
        Target environment. Selects the EnvironmentConfig carrying the per-provider
        topology. One of labul, labda, harvester.
    os : str, default is "ubuntu24", optional
        OS / image to use.
    count : str, default is "1", optional
        Number of VMs to create.
    ansible : bool, default is True, optional
        Run baseos Ansible provisioning after VM creation.
    providerRef : ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpecProviderRef, default is Undefined, optional
        Override the ProviderConfig reference.
    """


    size: "small" | "medium" | "large" | "xlarge"

    provider: "vsphere" | "proxmox" | "harvester"

    environment: "labul" | "labda" | "harvester"

    os?: "ubuntu24" | "sthings-u26" | "sthings-u26-k3s" | "rocky9-dev" | "sthings-rocky9" | "sthings-leap"

    count?: str

    ansible?: bool

    providerRef?: ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpecProviderRef


schema ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpecProviderRef:
    r"""
    Override the ProviderConfig reference.

    Attributes
    ----------
    name : str, default is "default", optional
        name
    kind : str, default is "ClusterProviderConfig", optional
        ProviderConfig or ClusterProviderConfig
    """


    name?: str = "default"

    kind?: "ProviderConfig" | "ClusterProviderConfig" = "ClusterProviderConfig"


schema ResourcesStuttgartThingsComV1alpha1XVirtualMachineStatus:
    r"""
    resources stuttgart things com v1alpha1 x virtual machine status

    Attributes
    ----------
    share : {str:any}, default is Undefined, optional
        Freeform field containing status information.
    vmReady : bool, default is Undefined, optional
        Whether the VM has been created.
    ansibleReady : bool, default is Undefined, optional
        Whether ansible provisioning completed.
    """


    share?: {str:any}

    vmReady?: bool

    ansibleReady?: bool
