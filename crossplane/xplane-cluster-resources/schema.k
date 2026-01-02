schema ProviderConfigParams:
    """
    Parameters for creating a ProviderConfig or ClusterProviderConfig
    """
    clusterName?: str = "target"
    """Name of the cluster/provider config"""

    credNamespace?: str = "crossplane-system"
    """Namespace where the credentials secret is stored"""

    credSecretName?: str = "target"
    """Name of the secret containing the kubeconfig"""

    credKey?: str = "config"
    """Key in the secret that contains the kubeconfig data"""

    providerConfigRef?: str = "helm-provider"
    """Reference name for the provider config"""

    providerType?: str = "helm"
    """Provider type: 'helm' or 'kubernetes'"""

    useClusterProviderConfig?: bool = False
    """If true, creates ClusterProviderConfig instead of ProviderConfig"""

    createProviderConfig?: bool
    """If true, includes the ProviderConfig/ClusterProviderConfig in output"""
