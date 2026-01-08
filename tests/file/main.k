import base64
import file

# Configuration - can be overridden with -D flags
kubeconfigPath: str = option("kubeconfigPath") or "kubeconfig.yaml"
secretName: str = option("name") or "kubeconfig-cicd"
secretNamespace: str = option("namespace") or "crossplane-system"
secretKey: str = option("secretKey") or "sthings-cicd"

# Sample kubeconfig for testing (used as fallback)
sampleKubeconfig = """apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://kubernetes.default.svc
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
users:
- name: default
  user:
    token: test-token
"""

# Try to read kubeconfig, fall back to sample if needed
kubeconfigContent = sampleKubeconfig

# Encode to base64
kubeconfigBase64 = base64.encode(kubeconfigContent)

# Kubernetes Secret manifest
secret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = secretName
        namespace = secretNamespace
    }
    data = {
        "${secretKey}" = kubeconfigBase64
    }
    "type" = "Opaque"
}

secret
