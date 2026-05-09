# Example: a kind cluster registered with clusterbook-operator.
#
# Usage:
#   kcl run main.k examples/kind.k
#
# Renders a ClusterbookCluster with `spec.clusterType: kind`,
# `spec.lbRange.{start,stop}` for the cilium-lb pool, and
# `spec.kubeconfigSecretRef.key: kubeconfig`. networkKey,
# providerConfigRef, and createDNS are intentionally omitted —
# the operator carves the LB range from the docker bridge and
# does not allocate a VIP for kind clusters.

_name = "kinde-dev2"
_clusterName = "kinde-dev2"
_clusterType = "kind"

# The docker-bridge IP range the cilium-lb-kind ApplicationSet
# carves into a CiliumLoadBalancerIPPool.
_lbRangeStart = "172.18.255.200"
_lbRangeStop = "172.18.255.250"

_kubeconfigSecretName = "kinde-dev2"  # pragma: allowlist secret
_kubeconfigSecretNamespace = "argocd"  # pragma: allowlist secret
_kubeconfigSecretKey = "kubeconfig"  # pragma: allowlist secret

_releaseOnDelete = True

_clusterLabels = {
    "auto-project" = "true"
    "kind-platform" = "true"
    "kind-platform/cilium-install" = "true"
    "kind-platform/cilium-lb" = "true"
    "kind-platform/cert-manager-install" = "true"
    "kind-platform/cert-manager-selfsigned" = "true"
}
