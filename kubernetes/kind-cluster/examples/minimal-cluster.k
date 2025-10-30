# Example: Minimal Cluster Configuration
# This creates a minimal cluster with just the API server port mapped
#
# Usage:
#   kcl run main.k examples/minimal-cluster.k

# Override to only map the API server
_extraPortMappings = [
    {containerPort = 6443, hostPort = 6443, protocol = "TCP"}
]

# Use standard Docker Hub (no custom mirror)
_registryMirror1 = "https://registry-1.docker.io"
_registryMirror2 = "https://registry-1.docker.io"
