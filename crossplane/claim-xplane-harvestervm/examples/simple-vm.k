"""
Simple example of creating a HarvesterVM using the KCL module.
Run with: kcl run examples/simple-vm.k
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_harvester_vm as harvestervm

# Create a simple Harvester VM
harvestervm.HarvesterVM {
    metadata = v1.ObjectMeta {
        name = "example-vm"
        namespace = "default"
    }

    spec = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec {
        providerConfigRef = "dev"

        volume = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume {
            pvcName = "example-vm-root"
            storageClassName = "harvester-longhorn"
            storage = "20Gi"
        }

        cloudInit = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit {
            vmName = "example-vm"
            hostname = "example"
            domain = "local"
            users = [
                harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser {
                    name = "ubuntu"
                    groups = "sudo"
                    shell = "/bin/bash"
                    sudo = "ALL=(ALL) NOPASSWD:ALL"
                }
            ]
            packages = ["qemu-guest-agent"]
            runcmd = [
                "systemctl enable qemu-guest-agent"
                "systemctl start qemu-guest-agent"
            ]
        }

        vm = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVm {
            description = "Example Harvester VM"
            os = "ubuntu"

            cpu = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmCpu {
                cores = 2
            }

            resources = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources {
                memory = "4Gi"
                cpu = "2"
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
                    networkName = "default/default"
                }
            ]
        }
    }
}
