# Example: recreate the `philly` ClusterbookCluster from the labul lab.
#
# Usage:
#   kcl run main.k examples/philly.k

_name = "philly"
_networkKey = "10.31.101"
_clusterName = "philly"

_createDNS = True
_preserveKubeconfigServer = True
_releaseOnDelete = True

_kubeconfigSecretName = "philly"  # pragma: allowlist secret
_kubeconfigSecretNamespace = "argocd"  # pragma: allowlist secret

_argocdNamespace = "argocd"

_providerConfigName = "default"

_clusterLabels = {
    "env" = "lab"
    "role" = "mgmt"
    "auto-project" = "true"
}
