"""
Simple example of creating a HarvesterVM using the KCL module directly.
Run with: kcl run examples/simple-vm.k

Infrastructure (providerConfigRef, storageClassName, namespace, networkName,
imageId) is inherited from the EnvironmentConfig selected by
`spec.environmentConfig`, so it is intentionally omitted here.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_harvester_vm as harvestervm

harvestervm.HarvesterVM {
    metadata = v1.ObjectMeta {
        name = "example-vm"
        namespace = "default"
    }
    spec = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec {
        environmentConfig = "default"
        volume = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume {
            pvcName = "example-vm-disk-0"
            storage = "20Gi"
            # Single-VM boot disk: ReadWriteOnce (RWX Block boot volume risks
            # corruption with RerunOnFailure).
            accessModes = ["ReadWriteOnce"]
            volumeMode = "Block"
        }
        cloudInit = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit {
            vmName = "example-vm"
            hostname = "example-vm"
            domain = "local"
            users = [
                harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser {
                    name = "sthings"
                    groups = "sudo"
                    shell = "/bin/bash"
                    sudo = "ALL=(ALL) NOPASSWD:ALL"
                }
            ]
            packages = ["qemu-guest-agent"]
            runcmd = [
                "systemctl enable --now qemu-guest-agent.service"
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
        }
    }
}
