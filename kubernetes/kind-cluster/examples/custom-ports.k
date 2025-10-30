# Example: Custom Port Mappings
# This file demonstrates how to override the default port mappings
# with a completely custom list.
#
# Usage:
#   kcl run main.k examples/custom-ports.k
#
# This overrides the _extraPortMappings variable in main.k

# Override the entire port mappings list
_extraPortMappings = [
    # API Server
    {containerPort = 6443, hostPort = 6443, protocol = "TCP"},

    # HTTP/HTTPS
    {containerPort = 80, hostPort = 8080},
    {containerPort = 443, hostPort = 8443},

    # Custom application ports
    {containerPort = 9090, hostPort = 9090},
    {containerPort = 3000, hostPort = 3000},
]
