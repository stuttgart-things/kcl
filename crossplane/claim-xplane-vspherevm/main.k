"""
Example usage of VsphereVM resource from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_vsphere_vm as vspherevm

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.vm?.spec or {}

# Template selector
_templateName = option("templateName") or _params?.templateName or "demo"  # Options: "demo", "production", "minimal"

# T-shirt size configurations (RAM in MB, Disk in GB, CPU cores)
_sizeConfigs = {
    "S": {"ram": "2048", "disk": "32", "cpu": "2"}
    "M": {"ram": "4096", "disk": "64", "cpu": "4"}
    "L": {"ram": "8192", "disk": "128", "cpu": "8"}
    "XL": {"ram": "16384", "disk": "256", "cpu": "16"}
    "XXL": {"ram": "32768", "disk": "512", "cpu": "32"}
}

# Size selector (optional - if set, overrides individual ram/disk/cpu values)
_size = option("size") or _params?.size or ""
_sizeConfig = _sizeConfigs[_size] if _size in _sizeConfigs else {}

# Common VM parameters
_vmSpec = _spec?.vm or {}
_name = _vmSpec?.name or option("name") or "demo-vm"
_namespace = option("namespace") or _params?.namespace or "default"

# Use size config if available, otherwise fall back to explicit values or defaults
_ram = str(_sizeConfig?.ram or _vmSpec?.ram or option("ram") or "4096")
_disk = str(_sizeConfig?.disk or _vmSpec?.disk or option("disk") or "64")
_cpu = str(_sizeConfig?.cpu or _vmSpec?.cpu or option("cpu") or "4")
_count = str(_vmSpec?.count or option("count") or "1")
_firmware = _vmSpec?.firmware or option("firmware") or "bios"

# vSphere infrastructure parameters
_folderPath = _vmSpec?.folderPath or option("folderPath") or "/Datacenter/vm/test"
_datacenter = _vmSpec?.datacenter or option("datacenter") or "Datacenter"
_datastore = _vmSpec?.datastore or option("datastore") or "datastore1"
_resourcePool = _vmSpec?.resourcePool or option("resourcePool") or "Resources"
_network = _vmSpec?.network or option("network") or "VM Network"
_template = _vmSpec?.template or option("template") or "ubuntu-22.04-template"

# Tfvars parameters
_tfvarsSpec = _spec?.tfvars or {}
_tfvarsSecretName = _tfvarsSpec?.secretName or option("tfvarsSecretName") or "vsphere-tfvars"
_tfvarsSecretNamespace = _tfvarsSpec?.secretNamespace or option("tfvarsSecretNamespace") or "crossplane-system"
_tfvarsSecretKey = _tfvarsSpec?.secretKey or option("tfvarsSecretKey") or "terraform.tfvars"

# Connection secret parameters
_connectionSecretSpec = _spec?.connectionSecret or {}
_connectionSecretName = _connectionSecretSpec?.name or option("connectionSecretName") or "${_name}-connection"
_connectionSecretNamespace = _connectionSecretSpec?.namespace or option("connectionSecretNamespace") or _namespace

# Provider reference parameters
_providerRefSpec = _spec?.providerRef or {}
_providerRefName = _providerRefSpec?.name or option("providerRefName") or "default"
_providerRefKind = _providerRefSpec?.kind or option("providerRefKind") or "ClusterProviderConfig"

# Demo Template - Basic VM for testing
if _templateName == "demo":
    vspherevm.VsphereVM {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "crossplane.io/managed-by": "kcl"
            }
        }

        spec = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpec {
            vm = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecVm {
                name = _name
                count = _count
                ram = _ram
                disk = _disk
                cpu = _cpu
                firmware = _firmware
                folderPath = _folderPath
                datacenter = _datacenter
                datastore = _datastore
                resourcePool = _resourcePool
                network = _network
                template = _template
            }
            tfvars = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecTfvars {
                secretName = _tfvarsSecretName
                secretNamespace = _tfvarsSecretNamespace
                secretKey = _tfvarsSecretKey
            }
            connectionSecret = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecConnectionSecret {
                name = _connectionSecretName
                namespace = _connectionSecretNamespace
            }
            providerRef = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecProviderRef {
                name = _providerRefName
                kind = _providerRefKind
            }
        }
    }

# Production Template - High-spec VM with production settings
if _templateName == "production":
    vspherevm.VsphereVM {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "crossplane.io/managed-by": "kcl"
                "environment": "production"
            }
            labels = {
                "app": _name
                "environment": "production"
                "tier": "compute"
            }
        }

        spec = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpec {
            vm = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecVm {
                name = _name
                count = option("count") or "1"
                ram = option("ram") or "16384"
                disk = option("disk") or "256"
                cpu = option("cpu") or "8"
                firmware = "efi"
                folderPath = option("folderPath") or "/Datacenter/vm/production"
                datacenter = _datacenter
                datastore = option("datastore") or "fast-ssd-datastore"
                resourcePool = option("resourcePool") or "Production-Pool"
                network = _network
                template = _template
                annotation = "Production VM managed by Crossplane - STUTTGART-THINGS"
                bootstrap = option("bootstrap") or '["echo PRODUCTION-VM"]'
            }
            tfvars = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecTfvars {
                secretName = _tfvarsSecretName
                secretNamespace = _tfvarsSecretNamespace
                secretKey = _tfvarsSecretKey
            }
            connectionSecret = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecConnectionSecret {
                name = _connectionSecretName
                namespace = _connectionSecretNamespace
            }
            providerRef = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecProviderRef {
                name = _providerRefName
                kind = _providerRefKind
            }
        }
    }

# Minimal Template - Bare minimum required fields
if _templateName == "minimal":
    vspherevm.VsphereVM {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
        }

        spec = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpec {
            vm = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecVm {
                name = _name
                ram = _ram
                disk = _disk
                cpu = _cpu
                folderPath = _folderPath
                datacenter = _datacenter
                datastore = _datastore
                resourcePool = _resourcePool
                network = _network
                template = _template
            }
            tfvars = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecTfvars {
                secretName = _tfvarsSecretName
            }
            connectionSecret = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecConnectionSecret {
                name = _connectionSecretName
            }
            providerRef = vspherevm.ResourcesStuttgartThingsComV1alpha1VsphereVMSpecProviderRef {
                name = _providerRefName
            }
        }
    }
