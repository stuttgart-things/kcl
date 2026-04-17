# Example: recreate the xplane-test AppProject
#
# Usage:
#   kcl run main.k examples/xplane-test.k

_name = "xplane-test"
_namespace = "argocd"

_sourceRepos = ["*"]

_destinations = [
    {server = "https://10.100.136.192:34360", namespace = "*"}
]

_clusterResourceWhitelist = [
    {group = "*", kind = "*"}
]
