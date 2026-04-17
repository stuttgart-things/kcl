# Example: minimal AppProject scoped to a single repo and in-cluster destination
#
# Usage:
#   kcl run main.k examples/minimal.k

_name = "team-platform"
_description = "Platform team project"

_sourceRepos = ["https://github.com/example/*"]

_destinations = [
    {server = "https://kubernetes.default.svc", namespace = "platform"}
]

_clusterResourceWhitelist = [
    {group = "", kind = "Namespace"}
]

_namespaceResourceWhitelist = [
    {group = "apps", kind = "Deployment"},
    {group = "", kind = "ConfigMap"},
]
