"""
Simple Ansible run example - execute baseos setup on two hosts.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_ansible_run as ansiblerun

ansiblerun.AnsibleRun {
    metadata = v1.ObjectMeta {
        name = "run-ansible-baseos"
        namespace = "default"
    }

    spec = ansiblerun.ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec {
        wrapInCrossplane = True
        crossplaneObjectName = "run-ansible-baseos"
        crossplaneNamespace = "default"
        crossplaneProviderConfig = "dev"

        pipelineRunName = "run-ansible-baseos"
        namespace = "tekton-ci"

        ansibleCredentialsSecretName = "ansible-credentials" # pragma: allowlist secret
        ansiblePlaybooks = [
            "sthings.baseos.setup"
        ]
        ansibleVarsFile = [
            "manage_filesystem+-true"
            "update_packages+-true"
            "ansible_become+-true"
            "ansible_become_method+-sudo"
        ]
        ansibleVarsInventory = [
            "all+[\"10.100.136.150\", \"10.100.136.151\"]"
        ]

        gitRepoUrl = "https://github.com/stuttgart-things/stage-time.git"
        gitRevision = "main"
        gitPath = "pipelines/execute-ansible-playbooks.yaml"

        installExtraRoles = "true"
        ansibleExtraRoles = [
            "https://github.com/stuttgart-things/install-requirements.git,2024.05.11"
        ]
        installExtraCollections = "true"
        ansibleExtraCollections = [
            "community.general:10.1.0"
            "https://github.com/stuttgart-things/ansible/releases/download/sthings-baseos-25.4.118.tar.gz/sthings-baseos-25.4.118.tar.gz"
        ]
    }
}
