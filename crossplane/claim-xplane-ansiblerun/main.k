"""
Example usage of AnsibleRun resource from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_ansible_run as ansiblerun

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ansiblerun?.spec or {}

# Template selector
_templateName = option("templateName") or _params?.templateName or "simple-run"

# Common parameters
_name = option("name") or _params?.name or "run-ansible"
_namespace = option("namespace") or _params?.namespace or "default"

# Ansible configuration
_ansibleCredentialsSecretName = option("ansibleCredentialsSecretName") or _spec?.ansibleCredentialsSecretName or "ansible-credentials"

# Playbooks: comma-separated string input, split into array
_playbooksRaw = option("playbooks") or _spec?.playbooks or "sthings.baseos.setup"
_playbooks = [p.strip() for p in _playbooksRaw.split(",")]

# Hosts: comma-separated string input (e.g. "10.100.136.150,10.100.136.151")
_hostsRaw = option("hosts") or _spec?.hosts or "10.100.136.150"
_hosts = [h.strip() for h in _hostsRaw.split(",")]
_hostGroup = option("hostGroup") or _spec?.hostGroup or "all"

# Build inventory entry: all+["host1","host2"]
_hostsFormatted = ", ".join(["\"{}\"".format(h) for h in _hosts])
_inventoryEntry = "{}+[{}]".format(_hostGroup, _hostsFormatted)

# Ansible vars file defaults
_ansibleVarsFileRaw = option("ansibleVarsFile") or ""
_ansibleVarsFileDefaults = [
    "manage_filesystem+-true"
    "update_packages+-true"
    "ansible_become+-true"
    "ansible_become_method+-sudo"
]
_ansibleVarsFile = [v.strip() for v in _ansibleVarsFileRaw.split(",")] if _ansibleVarsFileRaw else _ansibleVarsFileDefaults

# Crossplane configuration
_crossplaneProviderConfig = option("crossplaneProviderConfig") or _spec?.crossplaneProviderConfig or "dev"
_crossplaneNamespace = option("crossplaneNamespace") or _spec?.crossplaneNamespace or "default"

# Pipeline configuration
_pipelineNamespace = option("pipelineNamespace") or _spec?.pipelineNamespace or "tekton-ci"

# Git configuration
_gitRepoUrl = option("gitRepoUrl") or _spec?.gitRepoUrl or "https://github.com/stuttgart-things/stage-time.git"
_gitRevision = option("gitRevision") or _spec?.gitRevision or "main"
_gitPath = option("gitPath") or _spec?.gitPath or "pipelines/execute-ansible-playbooks.yaml"

# Extra roles and collections
_ansibleExtraRoles = [
    "https://github.com/stuttgart-things/install-requirements.git,2024.05.11"
]
_ansibleExtraCollections = [
    "community.general:10.1.0"
    "https://github.com/stuttgart-things/ansible/releases/download/sthings-baseos-25.4.118.tar.gz/sthings-baseos-25.4.118.tar.gz"
]

# Simple Run Template - based on claim-minimal.yaml
if _templateName == "simple-run":
    ansiblerun.AnsibleRun {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
        }

        spec = ansiblerun.ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec {
            # Crossplane configuration
            wrapInCrossplane = True
            crossplaneObjectName = _name
            crossplaneNamespace = _crossplaneNamespace
            crossplaneProviderConfig = _crossplaneProviderConfig

            # Pipeline configuration
            pipelineRunName = _name
            namespace = _pipelineNamespace

            # Ansible configuration
            ansibleCredentialsSecretName = _ansibleCredentialsSecretName
            ansiblePlaybooks = _playbooks
            ansibleVarsFile = _ansibleVarsFile
            ansibleVarsInventory = [_inventoryEntry]

            # Git configuration
            gitRepoUrl = _gitRepoUrl
            gitRevision = _gitRevision
            gitPath = _gitPath

            # Extra roles and collections
            installExtraRoles = "true"
            ansibleExtraRoles = _ansibleExtraRoles
            installExtraCollections = "true"
            ansibleExtraCollections = _ansibleExtraCollections
        }
    }
