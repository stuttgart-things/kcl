# Example: Development Cluster Configuration
# This creates a cluster suitable for local development
#
# Usage:
#   kcl run main.k examples/dev-cluster.k

# Development cluster naming
_clusterName = "dev-cluster"

# Use latest Kubernetes version
_nodeImage = "kindest/node:v1.35.0"

# Standard API server port
_apiServerPort = 6443

# Fewer port mappings for development
_portRangeStart = 30000
_portRangeCount = 3

# Local mount paths
_mountBasePath = "/tmp/dev-storage"

# Enable kube-proxy for easier debugging
_kubeProxyMode = "iptables"
