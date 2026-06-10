"""
This file describes the AnsibleRun XR (resources.stuttgart-things.com/v1alpha1).
It mirrors the CompositeResourceDefinition in
crossplane-configurations/cicd/ansible-run/apis/definition.yaml.

AnsibleRun is a Namespaced XR (Crossplane v2): it renders a Tekton PipelineRun
(wrapped in a kubernetes.m.crossplane.io Object) that runs Ansible playbooks
against a target host. Placement and shared defaults (git, image, collections,
credentials, namespace) come from the EnvironmentConfig selected by
`environmentConfig`; precedence is explicit XR value > EnvironmentConfig > KCL
module default.
"""
import ..k8s.apimachinery.pkg.apis.meta.v1


schema AnsibleRun:
    r"""
    resources stuttgart things com v1alpha1 ansible run

    Attributes
    ----------
    apiVersion : str, default is "resources.stuttgart-things.com/v1alpha1", required
        APIVersion defines the versioned schema of this representation of an object.
    kind : str, default is "AnsibleRun", required
        Kind is a string value representing the REST resource this object represents.
    metadata : v1.ObjectMeta, default is Undefined, optional
        metadata
    spec : ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec, default is Undefined, required
        spec
    status : ResourcesStuttgartThingsComV1alpha1AnsibleRunStatus, default is Undefined, optional
        status
    """


    apiVersion: "resources.stuttgart-things.com/v1alpha1" = "resources.stuttgart-things.com/v1alpha1"

    kind: "AnsibleRun" = "AnsibleRun"

    metadata?: v1.ObjectMeta

    spec: ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec

    status?: ResourcesStuttgartThingsComV1alpha1AnsibleRunStatus


schema ResourcesStuttgartThingsComV1alpha1AnsibleRunSpec:
    r"""
    resources stuttgart things com v1alpha1 ansible run spec

    Attributes
    ----------
    pipelineRunName : str, default is Undefined, required
        Name of the Tekton PipelineRun.
    namespace : str, default is "tekton-ci", required
        Namespace where the pipeline will run.
    storageSize : str, default is "20Mi", optional
        Size of the storage volume for the PipelineRun workspace PVC.
    storageAccessModes : str, default is "ReadWriteOnce", optional
        Storage access mode.
    storageClass : str, default is Undefined, optional
        StorageClass for the PipelineRun workspace PVC. When unset, the KCL
        module's default ("openebs-hostpath") is used.
    ansibleWorkingImage : str, default is Undefined, optional
        Ansible working container image. No default on purpose so the
        EnvironmentConfig's `ansibleWorkingImage` stays authoritative.
    createInventory : str, default is "true", optional
        Whether to create an Ansible inventory. One of "true", "false".
    ansibleTargetHost : str, default is "all", optional
        Ansible target host.
    ansibleVerbosity : str, default is "2", optional
        Ansible verbosity level.
    validateInventory : str, default is "true", optional
        Whether to validate the inventory. One of "true", "false".
    gitRepoUrl : str, default is "https://github.com/stuttgart-things/stage-time.git", required
        Git repository URL.
    gitRevision : str, default is Undefined, optional
        Git branch or revision. No default on purpose so the EnvironmentConfig's
        `gitRevision` stays authoritative.
    gitPath : str, default is Undefined, optional
        Path to the pipeline file in the Git repository.
    gitWorkspaceSubdirectory : str, default is "/ansible/workdir/", optional
        Workspace subdirectory for Ansible.
    ansibleCredentialsSecretName : str, default is Undefined, optional
        Name of the secret containing Ansible credentials. No default on purpose
        so the EnvironmentConfig's value stays authoritative.
    ansibleCredentialsUserKey : str, default is "ANSIBLE_USER", optional
        Key for the Ansible user in the credentials secret.
    ansibleCredentialsPasswordKey : str, default is "ANSIBLE_PASSWORD", optional
        Key for the Ansible password in the credentials secret.
    installExtraRoles : str, default is "true", optional
        Whether to install extra Ansible roles. One of "true", "false".
    ansibleExtraRoles : [str], default is Undefined, optional
        List of extra Ansible roles to install.
    installExtraCollections : str, default is "true", optional
        Whether to install extra Ansible collections. One of "true", "false".
    ansibleExtraCollections : [str], default is Undefined, optional
        List of extra Ansible collections to install.
    ansiblePlaybooks : [str], default is Undefined, required
        List of Ansible playbooks to execute.
    ansibleVarsFile : [str], default is Undefined, optional
        List of Ansible variables from file (e.g. "update_packages+-true").
    ansibleVarsInventory : [str], default is Undefined, optional
        List of Ansible inventory variables (e.g. 'all+["10.0.0.1"]').
    environmentConfig : str, default is "default", optional
        Selects the Crossplane EnvironmentConfig providing shared per-environment
        defaults (config-scoped label
        `ansible-run.resources.stuttgart-things.com/environment=<value>`).
    wrapInCrossplane : bool, default is True, optional
        Whether to wrap the pipeline in a Crossplane Object.
    crossplaneObjectName : str, default is Undefined, optional
        Name of the Crossplane object.
    crossplaneNamespace : str, default is "default", optional
        Namespace for the Crossplane object.
    crossplaneProviderConfig : str, default is "kubernetes-provider", optional
        Crossplane provider config to use.
    crossplaneTimeout : str, default is "60", optional
        Timeout for Crossplane operations.
    deriveReadiness : bool, default is True, optional
        When true, become Ready only once the PipelineRun's "Succeeded" condition
        is True.
    targetCluster : ResourcesStuttgartThingsComV1alpha1AnsibleRunSpecTargetCluster, default is Undefined, optional
        Target cluster configuration.
    """


    pipelineRunName: str

    namespace: str = "tekton-ci"

    storageSize?: str = "20Mi"

    storageAccessModes?: str = "ReadWriteOnce"

    storageClass?: str

    ansibleWorkingImage?: str

    createInventory?: "true" | "false" = "true"

    ansibleTargetHost?: str = "all"

    ansibleVerbosity?: str = "2"

    validateInventory?: "true" | "false" = "true"

    gitRepoUrl: str = "https://github.com/stuttgart-things/stage-time.git"

    gitRevision?: str

    gitPath?: str

    gitWorkspaceSubdirectory?: str = "/ansible/workdir/"

    ansibleCredentialsSecretName?: str

    ansibleCredentialsUserKey?: str = "ANSIBLE_USER"

    ansibleCredentialsPasswordKey?: str = "ANSIBLE_PASSWORD"

    installExtraRoles?: "true" | "false" = "true"

    ansibleExtraRoles?: [str]

    installExtraCollections?: "true" | "false" = "true"

    ansibleExtraCollections?: [str]

    ansiblePlaybooks: [str]

    ansibleVarsFile?: [str]

    ansibleVarsInventory?: [str]

    environmentConfig?: str = "default"

    wrapInCrossplane?: bool = True

    crossplaneObjectName?: str

    crossplaneNamespace?: str = "default"

    crossplaneProviderConfig?: str = "kubernetes-provider"

    crossplaneTimeout?: str = "60"

    deriveReadiness?: bool = True

    targetCluster?: ResourcesStuttgartThingsComV1alpha1AnsibleRunSpecTargetCluster


schema ResourcesStuttgartThingsComV1alpha1AnsibleRunSpecTargetCluster:
    r"""
    Target cluster configuration.

    Attributes
    ----------
    name : str, default is "in-cluster", optional
        Name of the ProviderConfig.
    scope : str, default is "Namespaced", optional
        Scope of the ProviderConfig. One of "Namespaced", "Cluster".
    """


    name?: str = "in-cluster"

    scope?: "Namespaced" | "Cluster" = "Namespaced"


schema ResourcesStuttgartThingsComV1alpha1AnsibleRunStatus:
    r"""
    resources stuttgart things com v1alpha1 ansible run status

    Attributes
    ----------
    installed : bool, default is Undefined, optional
        Whether the AnsibleRun has been installed.
    pipelineRunName : str, default is Undefined, optional
        Name of the rendered Tekton PipelineRun.
    succeeded : str, default is Undefined, optional
        The PipelineRun's "Succeeded" condition status.
    reason : str, default is Undefined, optional
        Reason of the PipelineRun's Succeeded condition.
    message : str, default is Undefined, optional
        Human-readable message from the PipelineRun's Succeeded condition.
    startTime : str, default is Undefined, optional
        When the PipelineRun started.
    completionTime : str, default is Undefined, optional
        When the PipelineRun completed.
    taskRuns : [ResourcesStuttgartThingsComV1alpha1AnsibleRunStatusTaskRuns], default is Undefined, optional
        The PipelineRun's child TaskRuns.
    """


    installed?: bool

    pipelineRunName?: str

    succeeded?: str

    reason?: str

    message?: str

    startTime?: str

    completionTime?: str

    taskRuns?: [ResourcesStuttgartThingsComV1alpha1AnsibleRunStatusTaskRuns]


schema ResourcesStuttgartThingsComV1alpha1AnsibleRunStatusTaskRuns:
    r"""
    A child TaskRun of the rendered PipelineRun.

    Attributes
    ----------
    name : str, default is Undefined, optional
        Name of the TaskRun.
    pipelineTaskName : str, default is Undefined, optional
        The pipeline task this TaskRun runs.
    """


    name?: str

    pipelineTaskName?: str
