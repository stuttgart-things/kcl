schema PersistentVolumeClaimConfig:
    """
    PersistentVolumeClaim configuration schema for Harvester HCI image-backed volumes

    Args:
        name: str, required - Name of the PVC
        namespace: str, default "default" - Namespace for the PVC
        imageNamespace: str, default "default" - Namespace of the Harvester image
        imageId: str, required - Harvester image ID (e.g., "image-t9w92")
        storage: str, default "10Gi" - Storage size request
        accessModes: [str], default ["ReadWriteMany"] - Access modes for the volume
        storageClass: str, required - Storage class base name (e.g., "longhorn")
        volumeMode: str, default "Block" - Volume mode (Block or Filesystem)
    """
    name: str
    namespace: str = "default"
    imageNamespace: str = "default"
    imageId: str
    storage: str = "10Gi"
    accessModes: [str] = ["ReadWriteMany"]
    storageClass: str
    volumeMode: str = "Block"

    check:
        len(name) > 0, "name cannot be empty"
        len(imageId) > 0, "imageId cannot be empty"
        len(storageClass) > 0, "storageClass cannot be empty"
        volumeMode in ["Block", "Filesystem"], "volumeMode must be Block or Filesystem"

schema CloudConfigSecretConfig:
    """
    Cloud-init configuration secret for Harvester VMs

    Args:
        name: str, required - Name of the secret
        namespace: str, default "default" - Namespace for the secret
        userdata: str, default "" - Base64 encoded cloud-init userdata
        networkdata: str, default "" - Base64 encoded network configuration
    """
    name: str
    namespace: str = "default"
    userdata: str = ""
    networkdata: str = ""

    check:
        len(name) > 0, "name cannot be empty"

schema VirtualMachineConfig:
    """
    KubeVirt VirtualMachine configuration for Harvester

    Args:
        name: str, required - Name of the VM
        namespace: str, default "default" - Namespace for the VM
        hostname: str, optional - Hostname for the VM (defaults to name if not set)
        description: str, default "" - Description annotation
        osLabel: str, default "linux" - OS label
        runStrategy: str, default "RerunOnFailure" - Run strategy
        cpuCores: int, default 8 - Number of CPU cores
        cpuSockets: int, default 1 - Number of CPU sockets
        cpuThreads: int, default 1 - Number of CPU threads
        memory: str, default "12Gi" - Memory allocation
        pvcName: str, required - Name of the PVC to use for disk
        secretName: str, required - Name of the cloud-init secret
        diskName: str, default "disk-0" - Name of the primary disk volume
        machineType: str, default "q35" - Machine type (q35, pc)
        networkNamespace: str, optional - Network namespace (defaults to VM namespace)
        networkName: str, default "vms" - Network name (without namespace prefix)
        evictionStrategy: str, default "LiveMigrateIfPossible" - Eviction strategy
        terminationGracePeriod: int, default 120 - Termination grace period in seconds
    """
    name: str
    namespace: str = "default"
    hostname: str = ""
    description: str = ""
    osLabel: str = "linux"
    runStrategy: str = "RerunOnFailure"
    cpuCores: int = 8
    cpuSockets: int = 1
    cpuThreads: int = 1
    memory: str = "12Gi"
    pvcName: str
    secretName: str
    diskName: str = "disk-0"
    machineType: str = "q35"
    networkNamespace: str = ""
    networkName: str = "vms"
    evictionStrategy: str = "LiveMigrateIfPossible"
    terminationGracePeriod: int = 120

    check:
        len(name) > 0, "name cannot be empty"
        len(pvcName) > 0, "pvcName cannot be empty"
        len(secretName) > 0, "secretName cannot be empty"
        cpuCores > 0, "cpuCores must be greater than 0"
        cpuSockets > 0, "cpuSockets must be greater than 0"
        cpuThreads > 0, "cpuThreads must be greater than 0"
