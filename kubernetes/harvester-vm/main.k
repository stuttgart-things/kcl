import schema

# Enable/disable resources (can be overridden via -D)
_enablePvcValue = option("enablePvc")
_enablePvcBool = True if _enablePvcValue == True or _enablePvcValue == "true" or _enablePvcValue == None else False

_enableCloudConfigValue = option("enableCloudConfig")
_enableCloudConfigBool = True if _enableCloudConfigValue == True or _enableCloudConfigValue == "true" or _enableCloudConfigValue == None else False

_enableVmValue = option("enableVm")
_enableVmBool = True if _enableVmValue == True or _enableVmValue == "true" or _enableVmValue == None else False

# PVC Configuration with defaults that can be overridden via -D
_pvcConfig = schema.PersistentVolumeClaimConfig {
    name = option("pvcName") or "dev2-disk-0"
    namespace = option("namespace") or "default"
    imageNamespace = option("imageNamespace") or "default"
    imageId = option("imageId") or "image-t9w92"
    storage = option("storage") or "10Gi"
    storageClass = option("storageClass") or "longhorn"
    volumeMode = option("volumeMode") or "Block"
    accessModes = option("accessModes") or ["ReadWriteMany"]
}

# Cloud Config Secret Configuration
_secretConfig = schema.CloudConfigSecretConfig {
    name = option("secretName") or "dev4"
    namespace = option("namespace") or "default"
    userdata = option("userdata") or ""
    networkdata = option("networkdata") or ""
}

# VirtualMachine Configuration
_vmConfig = schema.VirtualMachineConfig {
    name = option("vmName") or "dev2"
    namespace = option("namespace") or "default"
    hostname = option("hostname") or option("vmName") or "dev2"
    description = option("description") or "dev2 vm"
    osLabel = option("osLabel") or "linux"
    runStrategy = option("runStrategy") or "RerunOnFailure"
    cpuCores = option("cpuCores") or 8
    cpuSockets = option("cpuSockets") or 1
    cpuThreads = option("cpuThreads") or 1
    memory = option("memory") or "12Gi"
    pvcName = option("pvcName") or "dev2-disk-0"
    secretName = option("secretName") or "dev4"
    diskName = option("diskName") or "disk-0"
    machineType = option("machineType") or "q35"
    networkNamespace = option("networkNamespace") or option("namespace") or "default"
    networkName = option("networkName") or "vms"
    evictionStrategy = option("evictionStrategy") or "LiveMigrateIfPossible"
    terminationGracePeriod = option("terminationGracePeriod") or 120
}

# Construct full network name
_fullNetworkName = "${_vmConfig.networkNamespace}/${_vmConfig.networkName}"

# Define the PVC resource
_pvc = {
    apiVersion = "v1"
    kind = "PersistentVolumeClaim"
    metadata = {
        name = _pvcConfig.name
        namespace = _pvcConfig.namespace
        annotations = {
            "harvesterhci.io/imageId" = "${_pvcConfig.imageNamespace}/${_pvcConfig.imageId}"
        }
    }
    spec = {
        accessModes = _pvcConfig.accessModes
        resources = {
            requests = {
                storage = _pvcConfig.storage
            }
        }
        storageClassName = "${_pvcConfig.storageClass}-${_pvcConfig.imageId}"
        volumeMode = _pvcConfig.volumeMode
    }
}

# Define the Cloud Config Secret resource
_secret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = _secretConfig.name
        namespace = _secretConfig.namespace
    }
    type = "secret"
    data = {
        userdata = _secretConfig.userdata
        networkdata = _secretConfig.networkdata
    }
}

# Define the VirtualMachine resource
_vm = {
    apiVersion = "kubevirt.io/v1"
    kind = "VirtualMachine"
    metadata = {
        name = _vmConfig.name
        namespace = _vmConfig.namespace
        labels = {
            os = _vmConfig.osLabel
        }
        annotations = {
            description = _vmConfig.description
        }
    }
    spec = {
        runStrategy = _vmConfig.runStrategy
        template = {
            metadata = {
                labels = {
                    vmName = _vmConfig.name
                }
            }
            spec = {
                hostname = _vmConfig.hostname
                domain = {
                    machine = {
                        type = _vmConfig.machineType
                    }
                    cpu = {
                        cores = _vmConfig.cpuCores
                        sockets = _vmConfig.cpuSockets
                        threads = _vmConfig.cpuThreads
                    }
                    resources = {
                        limits = {
                            memory = _vmConfig.memory
                            cpu = str(_vmConfig.cpuCores)
                        }
                    }
                    devices = {
                        disks = [
                            {
                                name = _vmConfig.diskName
                                disk = {
                                    bus = "virtio"
                                }
                                bootOrder = 1
                            }
                            {
                                name = "cloudinitdisk"
                                disk = {
                                    bus = "virtio"
                                }
                            }
                        ]
                        interfaces = [
                            {
                                name = "default"
                                bridge = {}
                                model = "virtio"
                            }
                        ]
                        inputs = [
                            {
                                name = "tablet"
                                type = "tablet"
                                bus = "usb"
                            }
                        ]
                    }
                    features = {
                        acpi = {
                            enabled = True
                        }
                    }
                }
                evictionStrategy = _vmConfig.evictionStrategy
                networks = [
                    {
                        name = "default"
                        multus = {
                            networkName = _fullNetworkName
                        }
                    }
                ]
                volumes = [
                    {
                        name = _vmConfig.diskName
                        persistentVolumeClaim = {
                            claimName = _vmConfig.pvcName
                        }
                    }
                    {
                        name = "cloudinitdisk"
                        cloudInitNoCloud = {
                            secretRef = {
                                name = _vmConfig.secretName
                            }
                            networkDataSecretRef = {
                                name = _vmConfig.secretName
                            }
                        }
                    }
                ]
                terminationGracePeriodSeconds = _vmConfig.terminationGracePeriod
            }
        }
    }
}

# Generate items conditionally
_pvcResources = [_pvc] if _enablePvcBool else []
_cloudConfigResources = [_secret] if _enableCloudConfigBool else []
_vmResources = [_vm] if _enableVmBool else []
items = _pvcResources + _cloudConfigResources + _vmResources
