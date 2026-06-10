"""
Example usage of the XVirtualMachine XR from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.

The XVirtualMachine is intentionally thin: placement, credentials and topology
come from the EnvironmentConfig selected by `environment` + `provider`. The
claim only picks a t-shirt `size`, a `provider`, an `environment` and (optionally)
an `os`, VM `count`, `ansible` toggle and a `providerRef` override.

Templates
---------
minimal   : Just the XRD-required fields - size, provider, environment.
detailed  : All fields - adds os, count, ansible and a providerRef override.
harvester : Harvester-only preset (provider+environment=harvester). Exposes
            name, size, os and ansible; matches the proven vm-harvester-1 XR and
            the platform `virtualmachine-harvester` EnvironmentConfig.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_x_virtual_machine as vm

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.vm?.spec or {}

# Coerce a -D string / params value into a bool. Returns `fallback` when unset.
_asBool = lambda v, fallback: bool -> bool {
    fallback if (v == None or v == "") else (str(v).lower() in ["true", "1", "yes"])
}

# Template selector
_templateName = option("templateName") or _params?.templateName or "minimal"  # Options: "minimal", "detailed"

# Identity
_name = _spec?.name or option("name") or _params?.name or "demo-vm"
_claimNamespace = _spec?.claimNamespace or option("claimNamespace") or _params?.claimNamespace or "default"

# Required fields
_size = _spec?.size or option("size") or _params?.size or "small"
_provider = _spec?.provider or option("provider") or _params?.provider or "vsphere"
_environment = _spec?.environment or option("environment") or _params?.environment or "labul"

# Optional fields (defaults mirror the XRD)
_os = _spec?.os or option("os") or _params?.os or "ubuntu24"
_count = str(_spec?.count or option("count") or _params?.count or "1")  # str() so `-D count=3` stays a string
# Resolve `ansible` without `or` so an explicit `false` (a falsy bool) is not swallowed.
_ansibleOpt = option("ansible")
_ansibleRaw = _ansibleOpt if _ansibleOpt != Undefined else (_params?.ansible if _params?.ansible != Undefined else _spec?.ansible)
_ansible = _asBool(_ansibleRaw, True)

# providerRef override - only emitted when a name is explicitly provided.
_providerRefName = _spec?.providerRef?.name or option("providerRefName") or _params?.providerRefName or ""
_providerRefKind = _spec?.providerRef?.kind or option("providerRefKind") or _params?.providerRefKind or "ClusterProviderConfig"

# Minimal Template - only the XRD-required fields.
if _templateName == "minimal":
    vm.XVirtualMachine {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = vm.ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpec {
            size = _size
            provider = _provider
            environment = _environment
        }
    }

# Harvester Template - provider+environment fixed to harvester (KubeVirt VM on
# the remote Harvester via the `virtualmachine-harvester` EnvironmentConfig).
# Exposes only size, os and ansible; mirrors the proven vm-harvester-1 XR.
if _templateName == "harvester":
    vm.XVirtualMachine {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = vm.ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpec {
            size = _size
            provider = "harvester"
            environment = _spec?.environment or option("environment") or _params?.environment or "harvester"
            os = _os
            ansible = _ansible
        }
    }

# Detailed Template - every spec field, with an optional providerRef override.
if _templateName == "detailed":
    vm.XVirtualMachine {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = vm.ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpec {
            size = _size
            provider = _provider
            environment = _environment
            os = _os
            count = _count
            ansible = _ansible
            if _providerRefName:
                providerRef = vm.ResourcesStuttgartThingsComV1alpha1XVirtualMachineSpecProviderRef {
                    name = _providerRefName
                    kind = _providerRefKind
                }
        }
    }
