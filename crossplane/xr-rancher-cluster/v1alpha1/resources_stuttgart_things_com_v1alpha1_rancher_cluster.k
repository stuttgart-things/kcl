"""
This file describes the RancherCluster XR (resources.stuttgart-things.com/v1alpha1).
It mirrors the CompositeResourceDefinition in
crossplane-configurations/machinery/rancher-cluster/apis/definition.yaml.

RancherCluster is a Namespaced XR (Crossplane v2): it provisions a
provisioning.cattle.io Cluster on a Rancher management cluster, wires the
downstream kubeconfig into a provider-kubernetes ClusterProviderConfig,
bootstraps a namespace on the new cluster and (optionally) registers it in
Argo CD via clusterbook-operator. Placement and per-environment defaults
(providerConfigRef, distro, kubernetesVersion, rancherNamespace, the Harvester
infra fields, the Argo CD target) come from the EnvironmentConfig selected by
`environmentConfig`; anything set on this XR spec wins over the EnvironmentConfig.
"""
import ..k8s.apimachinery.pkg.apis.meta.v1


schema RancherCluster:
    r"""
    resources stuttgart things com v1alpha1 rancher cluster

    Attributes
    ----------
    apiVersion : str, default is "resources.stuttgart-things.com/v1alpha1", required
        APIVersion defines the versioned schema of this representation of an object.
    kind : str, default is "RancherCluster", required
        Kind is a string value representing the REST resource this object represents.
    metadata : v1.ObjectMeta, default is Undefined, optional
        metadata
    spec : ResourcesStuttgartThingsComV1alpha1RancherClusterSpec, default is Undefined, required
        spec
    status : ResourcesStuttgartThingsComV1alpha1RancherClusterStatus, default is Undefined, optional
        status
    """


    apiVersion: "resources.stuttgart-things.com/v1alpha1" = "resources.stuttgart-things.com/v1alpha1"

    kind: "RancherCluster" = "RancherCluster"

    metadata?: v1.ObjectMeta

    spec: ResourcesStuttgartThingsComV1alpha1RancherClusterSpec

    status?: ResourcesStuttgartThingsComV1alpha1RancherClusterStatus


schema ResourcesStuttgartThingsComV1alpha1RancherClusterSpec:
    r"""
    resources stuttgart things com v1alpha1 rancher cluster spec

    Attributes
    ----------
    name : str, default is Undefined, required
        Name of the Rancher cluster. Also the prefix of the Rancher-managed
        kubeconfig Secret (`<name>-kubeconfig`) and the name of the emitted
        downstream ClusterProviderConfig.
    environmentConfig : str, default is "default", optional
        Selects the EnvironmentConfig supplying per-environment defaults.
    providerConfigRef : str, default is Undefined, optional
        ClusterProviderConfig for the CONTROL-PLANE cluster where Crossplane runs.
        Falls back to the EnvironmentConfig when unset.
    rancherProviderConfigRef : str, default is Undefined, optional
        ClusterProviderConfig targeting the Rancher MANAGEMENT cluster. Defaults
        to providerConfigRef (Crossplane + Rancher co-located). Set to split them.
    distro : str, default is Undefined, optional
        Kubernetes distribution. One of k3s, rke2. Falls back to the
        EnvironmentConfig, then k3s.
    infrastructure : str, default is "generic", optional
        How the nodes are provisioned. One of generic, harvester.
    kubernetesVersion : str, default is Undefined, optional
        Rancher Kubernetes version, e.g. v1.34.7+k3s1 or v1.31.5+rke2r1.
    rancherNamespace : str, default is Undefined, optional
        Namespace on the management cluster holding the provisioning Cluster and
        the Rancher-managed kubeconfig Secret. Falls back to fleet-default.
    clusterLabels : {str:str}, default is Undefined, optional
        Extra labels for the provisioning.cattle.io Cluster.
    machineGlobalConfig : {str:any}, default is Undefined, optional
        Free-form rkeConfig.machineGlobalConfig passthrough (cni, disable, args).
    harvester : ResourcesStuttgartThingsComV1alpha1RancherClusterSpecHarvester, default is Undefined, optional
        VM node config for infrastructure: harvester.
    bootstrap : ResourcesStuttgartThingsComV1alpha1RancherClusterSpecBootstrap, default is Undefined, optional
        Resources to apply to the downstream cluster via the wired ClusterProviderConfig.
    argocd : ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocd, default is Undefined, optional
        Optional Argo CD registration via clusterbook-operator.
    """


    name: str

    environmentConfig?: str = "default"

    providerConfigRef?: str

    rancherProviderConfigRef?: str

    distro?: "k3s" | "rke2"

    infrastructure?: "generic" | "harvester" = "generic"

    kubernetesVersion?: str

    rancherNamespace?: str

    clusterLabels?: {str:str}

    machineGlobalConfig?: {str:any}

    harvester?: ResourcesStuttgartThingsComV1alpha1RancherClusterSpecHarvester

    bootstrap?: ResourcesStuttgartThingsComV1alpha1RancherClusterSpecBootstrap

    argocd?: ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocd


schema ResourcesStuttgartThingsComV1alpha1RancherClusterSpecHarvester:
    r"""
    VM node config for infrastructure: harvester. The infra-identity fields
    (cloudCredentialSecretName, imageName, networkName, vmNamespace, sshUser)
    fall back to the EnvironmentConfig.

    Attributes
    ----------
    cloudCredentialSecretName : str, default is Undefined, optional
        Rancher Harvester cloud credential, in `<namespace>:<name>` form.
    imageName : str, default is Undefined, optional
        Harvester VM image, `<namespace>/<name>`.
    networkName : str, default is Undefined, optional
        Harvester network, `<namespace>/<name>`.
    vmNamespace : str, default is Undefined, optional
        Harvester namespace the VMs are created in. Falls back to default.
    cpuCount : int, default is 2, optional
        vCPUs per node.
    memorySize : int, default is 4, optional
        Memory per node, in GiB.
    diskSize : int, default is 40, optional
        Root disk per node, in GiB.
    sshUser : str, default is Undefined, optional
        SSH user baked into the image. Falls back to ubuntu.
    quantity : int, default is 1, optional
        Number of nodes in the pool.
    userData : str, default is Undefined, optional
        cloud-init userData for the nodes (plain YAML).
    """


    cloudCredentialSecretName?: str

    imageName?: str

    networkName?: str

    vmNamespace?: str

    cpuCount?: int = 2

    memorySize?: int = 4

    diskSize?: int = 40

    sshUser?: str

    quantity?: int = 1

    userData?: str


schema ResourcesStuttgartThingsComV1alpha1RancherClusterSpecBootstrap:
    r"""
    Resources to apply to the DOWNSTREAM cluster via the wired ClusterProviderConfig.

    Attributes
    ----------
    namespace : str, default is "crossplane-bootstrap", optional
        Namespace to bootstrap on the downstream cluster.
    labels : {str:str}, default is Undefined, optional
        Labels for the downstream bootstrap namespace.
    """


    namespace?: str = "crossplane-bootstrap"

    labels?: {str:str}


schema ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocd:
    r"""
    Optional: register the provisioned cluster in Argo CD via clusterbook-operator.

    Attributes
    ----------
    register : bool, default is False, optional
        Enable Argo CD registration via clusterbook-operator.
    reservation : ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocdReservation, default is Undefined, optional
        IP/DNS reservation via clusterbook-operator.
    namespace : str, default is Undefined, optional
        Argo CD namespace. Falls back to the EnvironmentConfig, then argocd.
    providerConfigRef : str, default is Undefined, optional
        ClusterProviderConfig for the cluster running Argo CD + clusterbook-operator.
    server : str, default is Undefined, optional
        Optional override for the downstream cluster's direct API endpoint.
        Normally left unset (auto-discovered).
    labels : {str:str}, default is Undefined, optional
        Labels for the ClusterbookCluster / Argo CD cluster Secret.
    annotations : {str:str}, default is Undefined, optional
        Annotations for the ClusterbookCluster / Argo CD cluster Secret.
    """


    register?: bool = False

    reservation?: ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocdReservation

    namespace?: str

    providerConfigRef?: str

    server?: str

    labels?: {str:str}

    annotations?: {str:str}


schema ResourcesStuttgartThingsComV1alpha1RancherClusterSpecArgocdReservation:
    r"""
    IP/DNS reservation via clusterbook-operator.

    Attributes
    ----------
    enabled : bool, default is False, optional
        Reserve an IP (sets the ClusterbookCluster's skipReservation: false).
    networkKey : str, default is Undefined, optional
        Network prefix to reserve the IP from (e.g. '192.168.10').
    providerConfigRef : str, default is Undefined, optional
        ClusterbookProviderConfig name backing the reservation. Falls back to default.
    createDNS : bool, default is Undefined, optional
        Create the DNS record for the reserved IP. Defaults true when enabled.
    """


    enabled?: bool = False

    networkKey?: str

    providerConfigRef?: str

    createDNS?: bool


schema ResourcesStuttgartThingsComV1alpha1RancherClusterStatus:
    r"""
    resources stuttgart things com v1alpha1 rancher cluster status

    Attributes
    ----------
    kubeconfigSecret : str, default is Undefined, optional
        Name of the Rancher-managed kubeconfig Secret.
    clusterProviderConfig : str, default is Undefined, optional
        Name of the emitted downstream ClusterProviderConfig.
    argocdClusterSecret : str, default is Undefined, optional
        Name of the Argo CD cluster Secret clusterbook-operator generates.
    ready : bool, default is Undefined, optional
        ready
    """


    kubeconfigSecret?: str

    clusterProviderConfig?: str

    argocdClusterSecret?: str

    ready?: bool
