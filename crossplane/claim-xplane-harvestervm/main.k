"""
Example usage of HarvesterVM resource from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_harvester_vm as harvestervm

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.harvestervm?.spec or {}

# Template selector
_templateName = option("templateName") or _params?.templateName or "demo"  # Options: "demo", "production", "minimal"

# T-shirt size configurations (memory, storage, CPU cores)
_sizeConfigs = {
    "S": {"memory": "2Gi", "storage": "20Gi", "cpu": "2", "cores": 2}
    "M": {"memory": "4Gi", "storage": "40Gi", "cpu": "4", "cores": 4}
    "L": {"memory": "8Gi", "storage": "80Gi", "cpu": "8", "cores": 8}
    "XL": {"memory": "16Gi", "storage": "160Gi", "cpu": "16", "cores": 16}
    "XXL": {"memory": "32Gi", "storage": "320Gi", "cpu": "32", "cores": 32}
}

# Size selector (optional - if set, overrides individual memory/storage/cpu values)
_size = option("size") or _params?.size or ""
_sizeConfig = _sizeConfigs[_size] if _size in _sizeConfigs else {}

# Common parameters
_name = option("name") or _params?.name or "demo-harvester-vm"
_namespace = option("namespace") or _params?.namespace or "default"
_providerConfigRef = option("providerConfigRef") or _params?.providerConfigRef or "dev"

# Volume parameters
_volumeSpec = _spec?.volume or {}
_pvcName = option("pvcName") or _volumeSpec?.pvcName or "${_name}-root"
_volumeNamespace = option("volumeNamespace") or _volumeSpec?.namespace or _namespace
_storageClassName = option("storageClassName") or _volumeSpec?.storageClassName or "harvester-longhorn"
_storage = _sizeConfig?.storage or option("storage") or _volumeSpec?.storage or "20Gi"
_accessModes = _volumeSpec?.accessModes or ["ReadWriteOnce"]
_volumeMode = option("volumeMode") or _volumeSpec?.volumeMode or "Filesystem"

# CloudInit parameters
_cloudInitSpec = _spec?.cloudInit or {}
_vmName = option("vmName") or _cloudInitSpec?.vmName or _name
_cloudInitNamespace = option("cloudInitNamespace") or _cloudInitSpec?.namespace or _namespace
_hostname = option("hostname") or _cloudInitSpec?.hostname or _name.split("-")[0]
_domain = option("domain") or _cloudInitSpec?.domain or "stuttgart-things.local"
_timezone = option("timezone") or _cloudInitSpec?.timezone or "Europe/Berlin"
_packageUpdate = _cloudInitSpec?.packageUpdate if _cloudInitSpec?.packageUpdate != None else True
_packageUpgrade = _cloudInitSpec?.packageUpgrade if _cloudInitSpec?.packageUpgrade != None else False
_sshPasswordAuth = _cloudInitSpec?.sshPasswordAuth if _cloudInitSpec?.sshPasswordAuth != None else False
_disableRoot = _cloudInitSpec?.disableRoot if _cloudInitSpec?.disableRoot != None else True

# VM parameters
_vmSpec = _spec?.vm or {}
_description = option("description") or _vmSpec?.description or "Harvester VM managed by Crossplane"
_runStrategy = option("runStrategy") or _vmSpec?.runStrategy or "RerunOnFailure"
_evictionStrategy = option("evictionStrategy") or _vmSpec?.evictionStrategy or "LiveMigrateIfPossible"
_terminationGracePeriodSeconds = int(_vmSpec?.terminationGracePeriodSeconds or option("terminationGracePeriodSeconds") or 120)
_os = option("os") or _vmSpec?.os or "ubuntu"
_machineType = option("machineType") or _vmSpec?.machineType or "q35"

# CPU configuration - use size config if available
_cores = int(_sizeConfig?.cores or _vmSpec?.cpu?.cores or option("cores") or 4)
_sockets = int(_vmSpec?.cpu?.sockets or option("sockets") or 1)
_threads = int(_vmSpec?.cpu?.threads or option("threads") or 1)

# Resource configuration - use size config if available
_memory = _sizeConfig?.memory or option("memory") or _vmSpec?.resources?.memory or "8Gi"
_cpu = _sizeConfig?.cpu or option("cpuResource") or _vmSpec?.resources?.cpu or "4"

# Network configuration
_networkName = option("networkName") or "default/default"

# Demo Template - Basic VM for testing
if _templateName == "demo":
    harvestervm.HarvesterVM {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "crossplane.io/managed-by" = "kcl"
            }
        }

        spec = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec {
            providerConfigRef = _providerConfigRef

            volume = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume {
                pvcName = _pvcName
                namespace = _volumeNamespace
                storageClassName = _storageClassName
                storage = _storage
                accessModes = _accessModes
                volumeMode = _volumeMode
                labels = {
                    app = _name
                }
            }

            cloudInit = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit {
                vmName = _vmName
                namespace = _cloudInitNamespace
                hostname = _hostname
                domain = _domain
                timezone = _timezone
                users = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser {
                        name = "ubuntu"
                        groups = "sudo"
                        shell = "/bin/bash"
                        sudo = "ALL=(ALL) NOPASSWD:ALL"
                    }
                ]
                packages = [
                    "qemu-guest-agent"
                    "curl"
                    "vim"
                ]
                runcmd = [
                    "systemctl enable qemu-guest-agent"
                    "systemctl start qemu-guest-agent"
                ]
                packageUpdate = _packageUpdate
                packageUpgrade = _packageUpgrade
                sshPasswordAuth = _sshPasswordAuth
                disableRoot = _disableRoot
            }

            vm = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVm {
                description = _description
                runStrategy = _runStrategy
                evictionStrategy = _evictionStrategy
                terminationGracePeriodSeconds = _terminationGracePeriodSeconds
                os = _os
                machineType = _machineType

                cpu = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmCpu {
                    cores = _cores
                    sockets = _sockets
                    threads = _threads
                }

                resources = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources {
                    memory = _memory
                    cpu = str(_cpu)
                }

                disks = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmDisk {
                        name = "rootdisk"
                        bootOrder = 1
                    }
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmDisk {
                        name = "cloudinitdisk"
                    }
                ]

                networks = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmNetwork {
                        name = "default"
                        networkName = _networkName
                    }
                ]
            }
        }
    }

# Production Template - High-spec VM with production settings
if _templateName == "production":
    harvestervm.HarvesterVM {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "crossplane.io/managed-by" = "kcl"
                "environment" = "production"
            }
            labels = {
                app = _name
                environment = "production"
                tier = "compute"
            }
        }

        spec = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec {
            providerConfigRef = _providerConfigRef

            volume = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume {
                pvcName = _pvcName
                namespace = _volumeNamespace
                storageClassName = _storageClassName
                storage = option("storage") or "100Gi"
                accessModes = ["ReadWriteOnce"]
                volumeMode = "Filesystem"
                labels = {
                    app = _name
                    environment = "production"
                }
            }

            cloudInit = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit {
                vmName = _vmName
                namespace = _cloudInitNamespace
                hostname = _hostname
                domain = _domain
                timezone = _timezone
                users = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser {
                        name = "ubuntu"
                        groups = "sudo"
                        shell = "/bin/bash"
                        sudo = "ALL=(ALL) NOPASSWD:ALL"
                    }
                ]
                packages = [
                    "qemu-guest-agent"
                    "curl"
                    "vim"
                    "htop"
                    "jq"
                ]
                runcmd = [
                    "systemctl enable qemu-guest-agent"
                    "systemctl start qemu-guest-agent"
                ]
                packageUpdate = True
                packageUpgrade = True
                sshPasswordAuth = False
                disableRoot = True
            }

            vm = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVm {
                description = "Production VM - ${_name}"
                runStrategy = "RerunOnFailure"
                evictionStrategy = "LiveMigrateIfPossible"
                terminationGracePeriodSeconds = 180
                os = _os
                machineType = "q35"

                cpu = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmCpu {
                    cores = int(option("cores") or 8)
                    sockets = 1
                    threads = 1
                }

                resources = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources {
                    memory = option("memory") or "16Gi"
                    cpu = option("cpuResource") or "8"
                }

                disks = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmDisk {
                        name = "rootdisk"
                        bootOrder = 1
                    }
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmDisk {
                        name = "cloudinitdisk"
                    }
                ]

                networks = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmNetwork {
                        name = "default"
                        networkName = _networkName
                    }
                ]
            }
        }
    }

# Minimal Template - Bare minimum required fields
if _templateName == "minimal":
    harvestervm.HarvesterVM {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
        }

        spec = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec {
            providerConfigRef = _providerConfigRef

            volume = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume {
                pvcName = _pvcName
                storageClassName = _storageClassName
            }

            cloudInit = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit {
                vmName = _vmName
                hostname = _hostname
            }

            vm = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVm {
                cpu = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmCpu {
                    cores = _cores
                }

                resources = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources {
                    memory = _memory
                    cpu = str(_cpu)
                }

                disks = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmDisk {
                        name = "rootdisk"
                    }
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmDisk {
                        name = "cloudinitdisk"
                    }
                ]

                networks = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmNetwork {
                        name = "default"
                        networkName = _networkName
                    }
                ]
            }
        }
    }
