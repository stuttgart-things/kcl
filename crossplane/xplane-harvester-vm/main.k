import k8s.api.core.v1 as k8sv1

# ================================
# XR PARAMS
# ================================
_params = option("params")

_name = _params?.oxr?.spec.name or ""
_namespace = _params?.oxr?.spec.namespace or "default"
_vmName = _params?.oxr?.spec.vmName or _name
_hostname = _params?.oxr?.spec.hostname or _vmName
_description = _params?.oxr?.spec.description or "${_vmName} vm"

_providerConfig = _params?.oxr?.spec.providerConfigRef or "harvester"

# ================================
# PVC CONFIG
# ================================
_pvcName = _params?.oxr?.spec.pvcName or "${_vmName}-disk-0"
_imageNamespace = _params?.oxr?.spec.imageNamespace or "default"
_imageId = _params?.oxr?.spec.imageId or "image-generic"
_storage = _params?.oxr?.spec.storage or "10Gi"
_storageClass = _params?.oxr?.spec.storageClass or "longhorn"
_volumeMode = _params?.oxr?.spec.volumeMode or "Block"
_accessModes = _params?.oxr?.spec.accessModes or ["ReadWriteMany"]

# ================================
# SECRET CONFIG
# ================================
_secretName = _params?.oxr?.spec.secretName or "${_vmName}-cloud-init"
_userdata = _params?.oxr?.spec.userdata or ""
_networkdata = _params?.oxr?.spec.networkdata or ""

# ================================
# VM CONFIG
# ================================
_osLabel = _params?.oxr?.spec.osLabel or "linux"
_runStrategy = _params?.oxr?.spec.runStrategy or "RerunOnFailure"
_cpuCores = _params?.oxr?.spec.cpuCores or 4
_cpuSockets = _params?.oxr?.spec.cpuSockets or 1
_cpuThreads = _params?.oxr?.spec.cpuThreads or 1
_memory = _params?.oxr?.spec.memory or "8Gi"
_diskName = _params?.oxr?.spec.diskName or "disk-0"
_machineType = _params?.oxr?.spec.machineType or "q35"
_networkNamespace = _params?.oxr?.spec.networkNamespace or _namespace
_networkName = _params?.oxr?.spec.networkName or "vms"
_evictionStrategy = _params?.oxr?.spec.evictionStrategy or "LiveMigrateIfPossible"
_terminationGracePeriod = _params?.oxr?.spec.terminationGracePeriod or 120

_fullNetworkName = "${_networkNamespace}/${_networkName}"

# ================================
# ENABLE FLAGS
# ================================
_enablePvc = _params?.oxr?.spec.enablePvc == True
_enableSecret = _params?.oxr?.spec.enableSecret == True
_enableVm = False if _params?.oxr?.spec.enableVm == False else True

# ================================
# NAMESPACE OBJECT
# ================================
_enableNamespaceValue = _params?.oxr?.spec.enableNamespace
_enableNamespace = False if _enableNamespaceValue == False else False

namespaceObj = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "harvester-ns-${_namespace}"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "harvester-namespace-${_namespace}"
        }
    }
    spec = {
        providerConfigRef = {
            name = _providerConfig
        }
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Namespace"
                metadata = {
                    name = _namespace
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# ================================
# PVC OBJECT
# ================================
pvcObj = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = _pvcName
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "harvester-pvc-${_pvcName}"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        providerConfigRef = {
            name = _providerConfig
        }
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "PersistentVolumeClaim"
                metadata = {
                    name = _pvcName
                    namespace = _namespace
                    annotations = {
                        "harvesterhci.io/imageId" = "${_imageNamespace}/${_imageId}"
                    }
                }
                spec = {
                    accessModes = _accessModes
                    resources = {
                        requests = {
                            storage = _storage
                        }
                    }
                    storageClassName = "${_storageClass}-${_imageId}"
                    volumeMode = _volumeMode
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# ================================
# SECRET OBJECT
# ================================
secretObj = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = _secretName
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "harvester-secret-${_secretName}"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        providerConfigRef = {
            name = _providerConfig
        }
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = _secretName
                    namespace = _namespace
                }
                type = "Opaque"
                stringData = {
                    userdata = _userdata
                    networkdata = _networkdata
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# ================================
# VM OBJECT
# ================================
vmObj = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = _vmName
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "harvester-vm-${_vmName}"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        providerConfigRef = {
            name = _providerConfig
        }
        forProvider = {
            manifest = {
                apiVersion = "kubevirt.io/v1"
                kind = "VirtualMachine"
                metadata = {
                    name = _vmName
                    namespace = _namespace
                    labels = {
                        os = _osLabel
                    }
                    annotations = {
                        description = _description
                    }
                }
                spec = {
                    runStrategy = _runStrategy
                    template = {
                        metadata = {
                            labels = {
                                vmName = _vmName
                            }
                        }
                        spec = {
                            hostname = _hostname
                            terminationGracePeriodSeconds = _terminationGracePeriod
                            evictionStrategy = _evictionStrategy
                            domain = {
                                machine = {
                                    type = _machineType
                                }
                                cpu = {
                                    cores = _cpuCores
                                    sockets = _cpuSockets
                                    threads = _cpuThreads
                                }
                                resources = {
                                    limits = {
                                        memory = _memory
                                        cpu = str(_cpuCores)
                                    }
                                }
                                devices = {
                                    disks = [
                                        {
                                            name = _diskName
                                            disk = { bus = "virtio" }
                                            bootOrder = 1
                                        }
                                        {
                                            name = "cloudinitdisk"
                                            disk = { bus = "virtio" }
                                        }
                                    ]
                                    interfaces = [
                                        {
                                            name = "default"
                                            bridge = {}
                                            model = "virtio"
                                        }
                                    ]
                                }
                                features = {
                                    acpi = { enabled = True }
                                }
                            }
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
                                    name = _diskName
                                    persistentVolumeClaim = {
                                        claimName = _pvcName
                                    }
                                }
                                {
                                    name = "cloudinitdisk"
                                    cloudInitNoCloud = {
                                        secretRef = { name = _secretName }
                                        networkDataSecretRef = { name = _secretName }
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        }
        managementPolicies = ["*"]
    }
}

# ================================
# OUTPUT (ALWAYS LIST)
# ================================
_items = []

_items += [namespaceObj] if _enableNamespace else []

_items += [pvcObj] if _enablePvc else []
_items += [secretObj] if _enableSecret else []
_items += [vmObj] if _enableVm else []

items = _items
