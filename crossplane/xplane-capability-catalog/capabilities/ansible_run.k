import ..schema as s

# ansible-run — the AnsibleRun Configuration, not a provider.
#
# Named for the Configuration it configures, not for the tool. That is not
# cosmetic: the ansible-run Composition selects its EnvironmentConfig on the
# label `ansible-run.resources.stuttgart-things.com/environment`, this catalog
# derives that label from the entry name, and function-environment-configs
# requires EXACTLY ONE match — so an entry called `ansible` emits a label
# nothing selects, the Composition finds zero EnvironmentConfigs, and the error
# names the selector rather than the entry.
#
# The entry that shows what the schema had to accommodate, and the reason it is
# worth having a schema at all rather than three near-identical charts:
#
#   * NO providerConfig. Nothing here configures a provider; AnsibleRun renders
#     a Tekton PipelineRun. `providerConfig?` was optional from the start for
#     exactly this case.
#   * TWO credential keys rather than one JSON document, because the consumer is
#     a pipeline reading environment variables, not a Terraform provider parsing
#     a credentials blob.
#   * A LIST value. `ansibleExtraCollections` reaches Tekton as a parameter, and
#     a stringified list is rejected there with ParameterTypeMismatch — an error
#     naming the Tekton parameter and nothing about where the value came from.
#
# Values are transcribed from the ansible capability chart and from the
# ansible-run-defaults EnvironmentConfig that builds this fleet's VMs today.
ansibleRun: s.Capability = {
    name = "ansible-run"
    credentials = s.Credentials {
        # Plain keys: the pipeline reads them as environment variables.
        data = {
            ANSIBLE_USER = "{{ .vm_ssh_user }}"
            ANSIBLE_PASSWORD = "{{ .vm_ssh_password }}"
        }
        vaultKeys = ["vm_ssh_user", "vm_ssh_password"]
    }
    # Both derived, not defaulted. The pipeline looks the Secret up by name and
    # reads it in ITS OWN namespace, so a catalog default for either would be a
    # second source that silently diverges from what is actually created.
    credentialsNameField = "ansibleCredentialsSecretName"
    credentialsNamespaceField = "namespace"
    environmentLabelKey = "ansible-run.resources.stuttgart-things.com/environment"
    # The pipeline definition and where it runs. Facts about THIS cluster —
    # which namespace has the Tekton pipeline SA, which StorageClass exists —
    # so they are required rather than defaulted: a wrong storageClass leaves
    # the PipelineRun Pending on an unbound PVC, which reads like a stuck
    # pipeline rather than a missing class.
    required = ["namespace", "storageClass"]
    defaults = {
        gitRepoUrl = "https://github.com/stuttgart-things/stage-time.git"
        gitRevision = "main"
        gitPath = "pipelines/execute-ansible-playbooks.yaml"
        ansibleWorkingImage = "ghcr.io/stuttgart-things/sthings-ansible:14.0.0"
        # A LIST, deliberately — see the header. Pinned versions rather than
        # floating ones: a collection that moves under a running fleet changes
        # what every VM build does, without a single file changing here.
        ansibleExtraCollections = [
            "community.crypto:3.2.1"
            "community.general:13.0.1"
            "ansible.posix:2.2.0"
            "kubernetes.core:6.4.0"
            "community.docker:5.2.1"
            "community.vmware:6.2.0"
            "awx.awx:24.6.1"
            "community.hashi_vault:7.1.0"
            "ansible.netcommon:8.5.2"
            "https://github.com/stuttgart-things/ansible/releases/download/sthings-baseos-26.730.1176/sthings-baseos-26.730.1176.tar.gz"
            "https://github.com/stuttgart-things/ansible/releases/download/sthings-awx-26.729.1166/sthings-awx-26.729.1166.tar.gz"
            "https://github.com/stuttgart-things/ansible/releases/download/sthings-rke-26.730.1176/sthings-rke-26.730.1176.tar.gz"
            "https://github.com/stuttgart-things/ansible/releases/download/sthings-container-26.730.1176/sthings-container-26.730.1176.tar.gz"
        ]
    }
    optional = []
}
