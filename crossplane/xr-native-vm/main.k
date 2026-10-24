"""
NativeVsphereVM / NativeProxmoxVM XRs (resources.stuttgart-things.com/v1alpha1)
for the native VM compositions on machinery
(crossplane-configurations vsphere-vm / proxmox-vm).

Renders the same object the Backstage template create-vm renders for its
baseos use case, so a VM ordered through claim-machinery and one ordered
through Backstage look alike in machinery-xrs.

Templates (templateName = lab)
------------------------------
labda-vsphere : NativeVsphereVM, EnvironmentConfig vspherevm-labda
labul-proxmox : NativeProxmoxVM, EnvironmentConfig proxmoxvm-labul
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1 as xr

_params = option("params") or {}
_spec = _params?.vm?.spec or {}

# Coerce a -D string / params value into a bool. Returns `fallback` when unset.
_asBool = lambda v, fallback: bool -> bool {
    fallback if (v == None or v == "" or v == Undefined) else (str(v).lower() in ["true", "1", "yes"])
}

# Coerce a value into a list[str]. Accepts a real list (params/data file) or a
# comma-separated string (-D playbooks=a,b,c). Returns [] when unset.
_toList = lambda v -> [str] {
    [str(x) for x in v] if typeof(v) == "list" else ([] if (v == None or v == "" or v == Undefined) else [s.strip() for s in str(v).split(",") if s.strip() != ""])
}

_get = lambda k: str, fallback -> any {
    _spec?[k] or option(k) or _params?[k] or fallback
}

# Template selector: the lab decides the kind and the EnvironmentConfig.
_lab = _get("templateName", "labul-proxmox")
assert _lab in ["labda-vsphere", "labul-proxmox"], "templateName must be labda-vsphere or labul-proxmox, got ${_lab}"
_vsphere = _lab == "labda-vsphere"

# Same t-shirt sizes as Backstage create-vm.
_sizes = {
    small = {cpu = "2", memory = "4096", disk = "40"}
    medium = {cpu = "4", memory = "8192", disk = "64"}
    large = {cpu = "8", memory = "16384", disk = "100"}
    xlarge = {cpu = "16", memory = "24576", disk = "200"}
}
_sizeName = _get("size", "medium")
assert _sizeName in _sizes, "size must be one of small, medium, large, xlarge, got ${_sizeName}"
_size = _sizes[_sizeName]

_name = _get("name", "demo-vm")
_claimNamespace = _get("claimNamespace", "default")
_managementCluster = _get("managementCluster", "machinery")
_environmentConfig = _get("environmentConfig", "labda" if _vsphere else "labul")
# Explicit values beat the size; empty means "take it from the size".
_cpu = str(_get("cpu", _size.cpu))
_memory = str(_get("memory", _size.memory))
_disk = str(_get("disk", _size.disk))

_ansibleOpt = option("ansible")
_ansibleEnabled = _asBool(_ansibleOpt if _ansibleOpt != Undefined else _params?.ansible, True)
_playbooks = _toList(_get("playbooks", "")) or ["sthings.baseos.setup"]
_extraEnvSecretName = _get("extraEnvSecretName", "")

_metadata = v1.ObjectMeta {
    name = "${_name}-vm"
    namespace = _claimNamespace
    annotations = {
        "stuttgart-things.com/management-cluster" = _managementCluster
        # machinery-xrs does not prune: deleting is file first, then the XR.
        "kustomize.toolkit.fluxcd.io/prune" = "disabled"
    }
}

_ansible = {
    enabled = _ansibleEnabled
    pipelineNamespace = "tekton-ci"
    crossplaneProviderConfig = "in-cluster"
    if _extraEnvSecretName:
        extraEnvSecretName = _extraEnvSecretName
    playbooks = _playbooks
    varsFile = [
        "manage_filesystem+-true"
        "update_packages+-true"
        "vm_hostname+-${_name}"
        # Build marker: sthings.baseos.setup writes these to /etc/sthings/build.yaml.
        "sthings_build_source+-claim-machinery"
        "sthings_build_order+-${_name}-vm"
        "sthings_build_use_case+-baseos"
        "sthings_build_lab+-${'labda' if _vsphere else 'labul'}"
        "sthings_build_management_cluster+-${_managementCluster}"
        "sthings_build_method+-crossplane"
        "sthings_build_management_lab+-labda"
    ]
} if _ansibleEnabled else {enabled = False}

if _vsphere:
    xr.NativeVsphereVM {
        metadata = _metadata
        spec = xr.NativeVsphereVMSpec {
            environmentConfig = _environmentConfig
            vm = xr.NativeVsphereVMSpecVM {
                name = _name
                cpu = _cpu
                ram = _memory
                disk = _disk
                tagsPolicy = "Merge"
            }
            ansible = xr.NativeVsphereVMSpecAnsible {**_ansible}
        }
    }
else:
    xr.NativeProxmoxVM {
        metadata = _metadata
        spec = xr.NativeProxmoxVMSpec {
            environmentConfig = _environmentConfig
            vm = xr.NativeProxmoxVMSpecVM {
                name = _name
                cpu = _cpu
                memory = _memory
                disk = _disk
                agentEnabled = True
                tagsPolicy = "Merge"
            }
            cloudInit = xr.NativeProxmoxVMSpecCloudInit {
                ipv4Address = "dhcp"
            }
            ansible = xr.NativeProxmoxVMSpecAnsible {**_ansible}
        }
    }
