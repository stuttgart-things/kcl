"""
Example usage of the AnsibleRun XR from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.

The AnsibleRun renders a Tekton PipelineRun (wrapped in a kubernetes.m.crossplane.io
Object) that runs Ansible playbooks against a target host. Shared defaults (git
image, collections, credentials, namespace) come from the EnvironmentConfig
selected by `environmentConfig`; precedence is explicit XR value >
EnvironmentConfig > KCL default. So thin claims only pick the playbook(s), the
target host(s) and the crossplane wrap settings.

Templates
---------
minimal  : XRD-required fields (pipelineRunName, namespace, gitRepoUrl,
           ansiblePlaybooks) plus the wrap-Object inputs function-kcl needs.
detailed : Every spec field, for exercising the full XRD surface.
baseos   : Proven single-host preset - runs sthings.baseos.setup against a
           target host, mirrors the working xr-ansiblerun example. Everything
           else (image, collections, gitRevision) falls through to the
           ansible-run-defaults EnvironmentConfig.
"""

import json
import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_ansible_run as ar

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ansibleRun?.spec or {}

# Coerce a -D string / params value into a bool. Returns `fallback` when unset.
_asBool = lambda v, fallback: bool -> bool {
    fallback if (v == None or v == "") else (str(v).lower() in ["true", "1", "yes"])
}

# Coerce a value into a list[str]. Accepts a real list (params/data file) or a
# comma-separated string (-D hosts=a,b,c). Returns [] when unset.
_toList = lambda v -> [str] {
    [str(x) for x in v] if typeof(v) == "list" else \
        ([] if (v == None or v == "") else [s for s in str(v).split(",") if s != ""])
}

# Template selector
_templateName = option("templateName") or _params?.templateName or "minimal"  # Options: "minimal", "detailed", "baseos"

# Identity
_name = _spec?.name or option("name") or _params?.name or "ansible-run"
_claimNamespace = _spec?.claimNamespace or option("claimNamespace") or _params?.claimNamespace or "default"

# Required fields
_pipelineRunName = _spec?.pipelineRunName or option("pipelineRunName") or _params?.pipelineRunName or "run-ansible"
_namespace = _spec?.namespace or option("namespace") or _params?.namespace or "tekton-ci"
_gitRepoUrl = _spec?.gitRepoUrl or option("gitRepoUrl") or _params?.gitRepoUrl or "https://github.com/stuttgart-things/stage-time.git"
_playbooks = _toList(_spec?.ansiblePlaybooks or option("ansiblePlaybooks") or _params?.ansiblePlaybooks) or ["sthings.baseos.setup"]

# Target host(s) -> ansibleVarsInventory line 'all+["h1","h2"]'. Either pass a
# ready-made ansibleVarsInventory (data file) or a `hosts` list/CSV (baseos).
_hosts = _toList(_spec?.hosts or option("hosts") or _params?.hosts)
_varsInventory = _spec?.ansibleVarsInventory or (["all+" + json.encode(_hosts)] if _hosts else [])
_varsFile = _toList(_spec?.ansibleVarsFile or _params?.ansibleVarsFile or _params?.varsFile)

# Generic baseos setup vars (mirrors the proven xr-ansiblerun XR). Used by the
# baseos template when no explicit varsFile is given. manage_filesystem=false
# skips the LVM data-disk role; the rest do package updates + privilege
# escalation. Env-specific overrides (e.g. vault_instances) are appended by the
# caller, not baked in here.
_baseosVarsFileDefaults = [
    "manage_filesystem+-false"
    "update_packages+-true"
    "ansible_become+-true"
    "ansible_become_method+-sudo"
]

# Crossplane wrap inputs. Resolve wrapInCrossplane without `or` so an explicit
# `false` (a falsy bool) is not swallowed by the chain.
_wrapOpt = option("wrapInCrossplane")
_wrapRaw = _wrapOpt if _wrapOpt != Undefined else (_params?.wrapInCrossplane if _params?.wrapInCrossplane != Undefined else _spec?.wrapInCrossplane)
_wrapInCrossplane = _asBool(_wrapRaw, True)
_crossplaneObjectName = _spec?.crossplaneObjectName or option("crossplaneObjectName") or _params?.crossplaneObjectName or _pipelineRunName
_crossplaneNamespace = _spec?.crossplaneNamespace or option("crossplaneNamespace") or _params?.crossplaneNamespace or "default"
_crossplaneProviderConfig = _spec?.crossplaneProviderConfig or option("crossplaneProviderConfig") or _params?.crossplaneProviderConfig or "in-cluster"

# Optional / detailed fields
_environmentConfig = _spec?.environmentConfig or option("environmentConfig") or _params?.environmentConfig or "default"
_storageSize = _spec?.storageSize or option("storageSize") or _params?.storageSize or "20Mi"
_storageClass = _spec?.storageClass or option("storageClass") or _params?.storageClass or ""
_ansibleWorkingImage = _spec?.ansibleWorkingImage or option("ansibleWorkingImage") or _params?.ansibleWorkingImage or ""
_ansibleVerbosity = str(_spec?.ansibleVerbosity or option("ansibleVerbosity") or _params?.ansibleVerbosity or "2")
_gitRevision = _spec?.gitRevision or option("gitRevision") or _params?.gitRevision or ""
_gitPath = _spec?.gitPath or option("gitPath") or _params?.gitPath or ""
_ansibleCredentialsSecretName = _spec?.ansibleCredentialsSecretName or option("ansibleCredentialsSecretName") or _params?.ansibleCredentialsSecretName or ""
_extraCollections = _toList(_spec?.ansibleExtraCollections or _params?.ansibleExtraCollections)
_extraRoles = _toList(_spec?.ansibleExtraRoles or _params?.ansibleExtraRoles)
_crossplaneTimeout = str(_spec?.crossplaneTimeout or option("crossplaneTimeout") or _params?.crossplaneTimeout or "60")
# Resolve deriveReadiness without `or` so an explicit `false` is not swallowed.
_deriveOpt = option("deriveReadiness")
_deriveRaw = _deriveOpt if _deriveOpt != Undefined else (_params?.deriveReadiness if _params?.deriveReadiness != Undefined else _spec?.deriveReadiness)
_deriveReadiness = _asBool(_deriveRaw, True)

# Minimal Template - XRD-required fields plus the wrap-Object inputs.
if _templateName == "minimal":
    ar.AnsibleRun {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = ar.ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec {
            pipelineRunName = _pipelineRunName
            namespace = _namespace
            gitRepoUrl = _gitRepoUrl
            ansiblePlaybooks = _playbooks
            wrapInCrossplane = _wrapInCrossplane
            crossplaneObjectName = _crossplaneObjectName
            crossplaneNamespace = _crossplaneNamespace
            crossplaneProviderConfig = _crossplaneProviderConfig
        }
    }

# BaseOS Template - proven single-host preset. Runs sthings.baseos.setup against
# the given host(s); image/collections/gitRevision fall through to the
# ansible-run-defaults EnvironmentConfig. Mirrors the working xr-ansiblerun XR.
if _templateName == "baseos":
    ar.AnsibleRun {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = ar.ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec {
            pipelineRunName = _pipelineRunName
            namespace = _namespace
            gitRepoUrl = _gitRepoUrl
            ansiblePlaybooks = _playbooks
            ansibleVarsFile = _varsFile or _baseosVarsFileDefaults
            if _varsInventory:
                ansibleVarsInventory = _varsInventory
            wrapInCrossplane = _wrapInCrossplane
            crossplaneObjectName = _crossplaneObjectName
            crossplaneNamespace = _crossplaneNamespace
            crossplaneProviderConfig = _crossplaneProviderConfig
        }
    }

# Detailed Template - every spec field, for exercising the full XRD surface.
if _templateName == "detailed":
    ar.AnsibleRun {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = ar.ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec {
            pipelineRunName = _pipelineRunName
            namespace = _namespace
            storageSize = _storageSize
            if _storageClass:
                storageClass = _storageClass
            if _ansibleWorkingImage:
                ansibleWorkingImage = _ansibleWorkingImage
            ansibleVerbosity = _ansibleVerbosity
            gitRepoUrl = _gitRepoUrl
            if _gitRevision:
                gitRevision = _gitRevision
            if _gitPath:
                gitPath = _gitPath
            if _ansibleCredentialsSecretName:
                ansibleCredentialsSecretName = _ansibleCredentialsSecretName
            if _extraRoles:
                ansibleExtraRoles = _extraRoles
            if _extraCollections:
                ansibleExtraCollections = _extraCollections
            ansiblePlaybooks = _playbooks
            if _varsFile:
                ansibleVarsFile = _varsFile
            if _varsInventory:
                ansibleVarsInventory = _varsInventory
            environmentConfig = _environmentConfig
            deriveReadiness = _deriveReadiness
            wrapInCrossplane = _wrapInCrossplane
            crossplaneObjectName = _crossplaneObjectName
            crossplaneNamespace = _crossplaneNamespace
            crossplaneProviderConfig = _crossplaneProviderConfig
            crossplaneTimeout = _crossplaneTimeout
        }
    }
