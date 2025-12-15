"""
Crossplane Harvester VM Module

Renders Harvester VMs as Crossplane kubernetes.crossplane.io/v1alpha2/Object resources.
Uses XR spec fields from option("params")?.oxr?.spec for configuration.

This module wraps Harvester VM resources (PVC, Secret, VirtualMachine) into
Crossplane managed objects that can be provisioned through XRDs.

Usage with Crossplane XR:
  The XR spec should contain:
    name: vm name
    namespace: target namespace
    pvcName: persistent volume claim name
    secretName: cloud-init secret name
    vmName: virtual machine name
    ... other config fields
"""

import k8s.api.core.v1 as k8sv1

# === XR SPEC / PARAMETER DEFAULTS ===
# Uses optional chaining to safely access XR spec fields
# Pattern: params?.oxr?.spec.fieldName or default if params else default
_params = option("params")

# Basic VM configuration
_name = _params?.oxr?.spec.name or "" if _params else ""
_namespace = _params?.oxr?.spec.namespace or "default" if _params else "default"
_vmName = _params?.oxr?.spec.vmName or _name if _params else _name
_hostname = _params?.oxr?.spec.hostname or _vmName if _params else _vmName
_description = _params?.oxr?.spec.description or "${_vmName} vm" if _params else "${_vmName} vm"

# PVC configuration
_pvcName = _params?.oxr?.spec.pvcName or "${_vmName}-disk-0" if _params else "${_vmName}-disk-0"
_imageNamespace = _params?.oxr?.spec.imageNamespace or "default" if _params else "default"
_imageId = _params?.oxr?.spec.imageId or "image-generic" if _params else "image-generic"
_storage = _params?.oxr?.spec.storage or "10Gi" if _params else "10Gi"
_storageClass = _params?.oxr?.spec.storageClass or "longhorn" if _params else "longhorn"
_volumeMode = _params?.oxr?.spec.volumeMode or "Block" if _params else "Block"
_accessModes = _params?.oxr?.spec.accessModes or ["ReadWriteMany"] if _params else ["ReadWriteMany"]

# Secret configuration
_secretName = _params?.oxr?.spec.secretName or "${_vmName}-cloud-init" if _params else "${_vmName}-cloud-init"
_userdata = _params?.oxr?.spec.userdata or "" if _params else ""
_networkdata = _params?.oxr?.spec.networkdata or "" if _params else ""

# VM resource configuration
_osLabel = _params?.oxr?.spec.osLabel or "linux" if _params else "linux"
_runStrategy = _params?.oxr?.spec.runStrategy or "RerunOnFailure" if _params else "RerunOnFailure"
_cpuCores = _params?.oxr?.spec.cpuCores or 4 if _params else 4
_cpuSockets = _params?.oxr?.spec.cpuSockets or 1 if _params else 1
_cpuThreads = _params?.oxr?.spec.cpuThreads or 1 if _params else 1
_memory = _params?.oxr?.spec.memory or "8Gi" if _params else "8Gi"
_diskName = _params?.oxr?.spec.diskName or "disk-0" if _params else "disk-0"
_machineType = _params?.oxr?.spec.machineType or "q35" if _params else "q35"
_networkNamespace = _params?.oxr?.spec.networkNamespace or _namespace if _params else _namespace
_networkName = _params?.oxr?.spec.networkName or "vms" if _params else "vms"
_evictionStrategy = _params?.oxr?.spec.evictionStrategy or "LiveMigrateIfPossible" if _params else "LiveMigrateIfPossible"
_terminationGracePeriod = _params?.oxr?.spec.terminationGracePeriod or 120 if _params else 120

# Control flags
_enablePvcValue = _params?.oxr?.spec.enablePvc if _params else None
_enablePvc = True if _enablePvcValue == True or _enablePvcValue == "true" else False

_enableSecretValue = _params?.oxr?.spec.enableSecret if _params else None  # pragma: allowlist secret
_enableSecret = True if _enableSecretValue == True or _enableSecretValue == "true" else False  # pragma: allowlist secret

_enableVmValue = _params?.oxr?.spec.enableVm if _params else None
_enableVm = True if _enableVmValue == True or _enableVmValue == "true" else False

# Construct full network name
_fullNetworkName = "${_networkNamespace}/${_networkName}"

# Safe cluster name for labels (replace dots and underscores with dashes)
_safeClusterName = "harvester-cluster"

# === RESOURCE GENERATORS ===

# Generate PVC as Crossplane Object
_generatePvc = lambda -> {str: any} {
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = _pvcName
            labels = {
                "app.kubernetes.io/name" = "harvester-pvc"
                "app.kubernetes.io/instance" = _pvcName
                "app.kubernetes.io/managed-by" = "crossplane"
            }
        }
        spec = {
            deletionPolicy = "Delete"
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
}

# Generate Secret as Crossplane Object
_generateSecret = lambda -> {str: any} {
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = _secretName
            labels = {
                "app.kubernetes.io/name" = "harvester-cloud-init"
                "app.kubernetes.io/instance" = _secretName
                "app.kubernetes.io/managed-by" = "crossplane"
            }
        }
        spec = {
            deletionPolicy = "Delete"
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = _secretName
                        namespace = _namespace
                    }
                    type = "secret"  # pragma: allowlist secret
                    data = {
                        userdata = _userdata
                        networkdata = _networkdata
                    }
                }
            }
            managementPolicies = ["*"]
        }
    }
}

# Generate VirtualMachine as Crossplane Object
_generateVm = lambda -> {str: any} {
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = _vmName
            labels = {
                "app.kubernetes.io/name" = "harvester-vm"
                "app.kubernetes.io/instance" = _vmName
                "app.kubernetes.io/managed-by" = "crossplane"
            }
        }
        spec = {
            deletionPolicy = "Delete"
            forProvider = {
                manifest = {
                    apiVersion = "kubevirt.io/v1"
                    kind = "VirtualMachine"
                    metadata = {
                        name = _vmName
                        namespace = _namespace
                        labels = {
                            "os" = _osLabel
                        }
                        annotations = {
                            "description" = _description
                        }
                    }
                    spec = {
                        runStrategy = _runStrategy
                        template = {
                            metadata = {
                                labels = {
                                    "vmName" = _vmName
                                }
                            }
                            spec = {
                                hostname = _hostname
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
                                evictionStrategy = _evictionStrategy
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
                                            secretRef = {
                                                name = _secretName
                                            }
                                            networkDataSecretRef = {
                                                name = _secretName
                                            }
                                        }
                                    }
                                ]
                                terminationGracePeriodSeconds = _terminationGracePeriod
                            }
                        }
                    }
                }
            }
            managementPolicies = ["*"]
        }
    }
}

# === OUTPUT GENERATION ===

# Build items array with only enabled resources
# Order: PVC -> Secret -> VM
_pvcItems = [_generatePvc()] if _enablePvc else []
_secretItems = [_generateSecret()] if _enableSecret else []
_vmItems = [_generateVm()] if _enableVm else []

# Combine all items in proper order
_allItems = _pvcItems + _secretItems + _vmItems

# Output: Direct resource if single, list if multiple
items = _allItems[0] if len(_allItems) == 1 else _allItems
