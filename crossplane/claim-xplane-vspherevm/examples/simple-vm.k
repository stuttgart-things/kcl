"""
Example: Simple vSphere VM claim
"""
import ..v1alpha1

# Create a simple vSphere VM
vm = v1alpha1.VsphereVM {
    metadata = {
        name = "my-test-vm"
        namespace = "default"
    }
    spec = {
        vm = {
            name = "my-test-vm"
            ram = "8192"
            disk = "128"
            cpu = "8"
            folderPath = "/Datacenter/vm/test"
            datacenter = "Datacenter"
            datastore = "datastore1"
            resourcePool = "Resources"
            network = "VM Network"
            template = "ubuntu-22.04-template"
        }
        tfvars = {
            secretName = "vsphere-tfvars" # pragma: allowlist secret
            secretNamespace = "crossplane-system" # pragma: allowlist secret
        }
        connectionSecret = {
            name = "my-test-vm-connection"
            namespace = "default"
        }
        providerRef = {
            name = "default"
            kind = "ClusterProviderConfig"
        }
    }
}
