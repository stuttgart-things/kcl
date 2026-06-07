"""
HarvesterVM generator (Crossplane v2, EnvironmentConfig model).

Emits a single namespaced `HarvesterVM` XR for the `harvester-vm` Configuration
(stuttgart-things/crossplane-configurations -> machinery/harvester-vm).

Design (see issue #53):
  * Adopts the EnvironmentConfig model. Per-environment infrastructure
    (providerConfigRef, storageClassName, namespace, networkName, imageId) is
    inherited from the EnvironmentConfig selected by `spec.environmentConfig`.
    Those fields are emitted ONLY when explicitly overridden, so the
    EnvironmentConfig wins by default.
  * One parameterized path (t-shirt `size` + `hardened` bool) instead of the
    old demo/production/minimal template trio.
  * Boot disk defaults to ReadWriteOnce (a RWX Block boot volume risks
    corruption with RerunOnFailure) — aligned with crossplane-configurations#32.

Usage:
    kcl run . -D name=dev9 -D size=L
    kcl run . -D name=dev9 -D size=M -D image=ubuntu25 -D hardened=true
    kcl run . -D name=db01 -D size=XL -D sshKey="ssh-rsa AAAA..." \
              -D providerConfigRef=harvester -D networkName=default/vms
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_harvester_vm as harvestervm

# Parameters from the claims API (params) or CLI (-D options).
_params = option("params") or {}

# --- helpers -----------------------------------------------------------------
# Coerce a -D string / params value into a bool. Returns `fallback` when unset
# (None or empty string), so optional booleans fall back to e.g. `hardened`.
_asBool = lambda v, fallback: bool -> bool {
    fallback if (v == None or v == "") else (str(v).lower() in ["true", "1", "yes"])
}

# --- EnvironmentConfig selector ----------------------------------------------
_environmentConfig = option("environmentConfig") or _params?.environmentConfig or "default"

# --- identity ----------------------------------------------------------------
_name = option("name") or _params?.name or "harvester-vm"
# where the XR object lives
_namespace = option("namespace") or _params?.namespace or "default"
_pvcName = option("pvcName") or _params?.pvcName or "${_name}-disk-0"
_vmName = option("vmName") or _params?.vmName or _name
_hostname = option("hostname") or _params?.hostname or _name

# --- t-shirt sizing ----------------------------------------------------------
# size drives cpu cores, memory, cpu resource string and root-disk storage.
_sizeConfigs = {
    "S": {"cores": 2, "memory": "2Gi", "cpu": "2", "storage": "20Gi"}
    "M": {"cores": 4, "memory": "4Gi", "cpu": "4", "storage": "40Gi"}
    "L": {"cores": 8, "memory": "8Gi", "cpu": "8", "storage": "80Gi"}
    "XL": {"cores": 16, "memory": "16Gi", "cpu": "16", "storage": "160Gi"}
    "XXL": {"cores": 32, "memory": "32Gi", "cpu": "32", "storage": "320Gi"}
}
_size = option("size") or _params?.size or "M"
_sizeConfig = _sizeConfigs[_size] if _size in _sizeConfigs else {}

# Explicit overrides win over the t-shirt size (Expert use), then size, then a
# built-in fallback.
_cores = int(option("cores") or _sizeConfig?.cores or 4)
_memory = option("memory") or _sizeConfig?.memory or "4Gi"
_cpuResource = str(option("cpuResource") or _sizeConfig?.cpu or "4")
_storage = option("storage") or _sizeConfig?.storage or "40Gi"

# --- image catalog -----------------------------------------------------------
# Single source of truth shared with the ClaimTemplate enums. The default
# `inherit` omits volume.imageId so it comes from the EnvironmentConfig.
#
# NOTE: the image ids below are environment-specific (Harvester assigns them on
# upload). Reconcile this map with the images actually present in your Harvester
# (`kubectl -n <ns> get virtualmachineimages`) before relying on a non-inherit
# alias. Day-to-day, prefer `inherit` and let the EnvironmentConfig supply the
# base image.
_imageCatalog = {
    "ubuntu25": "default/image-t9w92"
    "ubuntu22": "default/image-lg5qf"
    "rocky9": "default/image-k7m2x"
    "rocky8": "default/image-r4n9p"
    "debian12": "default/image-d3b7k"
    "opensuse15": "default/image-s5v2m"
    "opensuse-micro": "default/image-m5bh6"
}
_image = option("image") or _params?.image or "inherit"

# A direct imageId (full `namespace/image-xxx`) always wins; otherwise resolve
# the alias; `inherit` / unknown alias -> "" -> field omitted -> EnvironmentConfig.
_imageId = (option("imageId") or _params?.imageId or "") or (_imageCatalog[_image] if _image in _imageCatalog else "")

# --- env-sourced overrides (emitted only when set -> EnvironmentConfig wins) --
_providerConfigRef = option("providerConfigRef") or _params?.providerConfigRef or ""
_storageClassName = option("storageClassName") or _params?.storageClassName or ""
_targetNamespace = option("targetNamespace") or _params?.targetNamespace or ""
_networkName = option("networkName") or _params?.networkName or ""

# --- root-disk volume --------------------------------------------------------
# ReadWriteOnce by default: a RWX Block boot volume invites a second instance
# attaching the same disk (corruption risk with RerunOnFailure).
_accessModes = option("accessModes") or _params?.volume?.accessModes or ["ReadWriteOnce"]
_volumeMode = option("volumeMode") or _params?.volume?.volumeMode or "Block"

# --- cloud-init --------------------------------------------------------------
_hardened = _asBool(option("hardened") or _params?.hardened, False)
_domain = option("domain") or _params?.domain or "local"
_timezone = option("timezone") or _params?.timezone or "Europe/Berlin"
_user = option("user") or _params?.user or "sthings"
_sshKey = option("sshKey") or _params?.sshKey or ""

# hardened tightens the OS posture; the relaxed defaults favour dev convenience.
_packageUpdate = _asBool(option("packageUpdate"), True)
_packageUpgrade = _asBool(option("packageUpgrade"), _hardened)
_sshPasswordAuth = _asBool(option("sshPasswordAuth"), not _hardened)
_disableRoot = _asBool(option("disableRoot"), _hardened)

# Always keep qemu-guest-agent (the VMI needs it to report an IP), then append
# any user-requested packages without duplicating it.
_extraPackages = option("packages") or _params?.packages or []
_packages = ["qemu-guest-agent"] + [p for p in _extraPackages if p != "qemu-guest-agent"]

# --- vm ----------------------------------------------------------------------
_description = option("description") or _params?.description or "${_name} VM provisioned by Crossplane"
_os = option("os") or _params?.os or "ubuntu"
_machineType = option("machineType") or _params?.machineType or "q35"
_runStrategy = option("runStrategy") or _params?.runStrategy or "RerunOnFailure"
_evictionStrategy = option("evictionStrategy") or _params?.evictionStrategy or "LiveMigrateIfPossible"
_terminationGracePeriodSeconds = int(option("terminationGracePeriodSeconds") or _params?.terminationGracePeriodSeconds or 120)

# --- optional Ansible provisioning -------------------------------------------
_ansibleEnabled = _asBool(option("ansibleEnabled") or _params?.ansible?.enabled, False)

# --- render ------------------------------------------------------------------
harvestervm.HarvesterVM {
    metadata = v1.ObjectMeta {
        name = _name
        namespace = _namespace
        annotations = {
            "crossplane.io/managed-by" = "kcl"
        }
        labels = {
            app = _name
        }
    }
    spec = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpec {
        environmentConfig = _environmentConfig
        if _providerConfigRef:
            providerConfigRef = _providerConfigRef
        volume = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVolume {
            pvcName = _pvcName
            storage = _storage
            accessModes = _accessModes
            volumeMode = _volumeMode
            if _storageClassName:
                storageClassName = _storageClassName
            if _targetNamespace:
                namespace = _targetNamespace
            if _imageId:
                imageId = _imageId
            labels = {
                app = _name
            }
        }
        cloudInit = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInit {
            vmName = _vmName
            hostname = _hostname
            if _targetNamespace:
                namespace = _targetNamespace
            domain = _domain
            timezone = _timezone
            users = [
                harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecCloudInitUser {
                    name = _user
                    groups = "sudo"
                    shell = "/bin/bash"
                    sudo = "ALL=(ALL) NOPASSWD:ALL"
                    lockPasswd = False
                    if _sshKey:
                        sshAuthorizedKeys = [_sshKey]
                }
            ]
            packages = _packages
            runcmd = [
                "systemctl enable --now qemu-guest-agent.service"
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
                sockets = 1
                threads = 1
            }
            resources = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmResources {
                memory = _memory
                cpu = _cpuResource
            }
            # Networks inherit from the EnvironmentConfig unless overridden.
            if _networkName:
                networks = [
                    harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecVmNetwork {
                        name = "default"
                        networkName = _networkName
                    }
                ]
        }
        if _ansibleEnabled:
            ansible = harvestervm.ResourcesStuttgartThingsComV1alpha1HarvesterVMSpecAnsible {
                enabled = True
            }
    }
}
