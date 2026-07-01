# Example: Ingress-ready Cluster Configuration
# Control-plane labelled `ingress-ready=true` with 80/443 published on the host,
# suitable for ingress-nginx (or similar) on kind.
#
# Usage:
#   kcl run main.k examples/ingress-cluster.k

_clusterName = "ingress-cluster"

# Single worker is plenty for an ingress demo
_workerCount = 1

# Add the ingress-ready node label + publish HTTP/HTTPS host ports
_ingressReady = True
_ingressHttpHostPort = 80
_ingressHttpsHostPort = 443
