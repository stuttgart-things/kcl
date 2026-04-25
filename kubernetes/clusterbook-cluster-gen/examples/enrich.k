# Example: enrich an existing ArgoCD cluster Secret instead of creating one.
#
# Usage:
#   kcl run main.k examples/enrich.k

_name = "denver"
_networkKey = "10.31.103"
_clusterName = "denver"

_createDNS = True
_useFQDNAsServer = True
_serverSubdomain = "api"
_serverPort = 6443

# enrich mode: clusterbook only merges labels/annotations onto this Secret
_existingSecretRef = {
    name = "denver-cluster"
    namespace = "argocd"
}

_clusterLabels = {
    "env" = "lab"
    "role" = "edge"
}
