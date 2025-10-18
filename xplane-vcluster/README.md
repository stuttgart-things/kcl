# Crossplane VCluster KCL Module

This KCL module creates a Crossplane Helm Release for deploying VCluster with production-ready configuration and automatic connection secret management.

## Features

- **VCluster Deployment**: Creates VCluster instances via Crossplane Helm Provider
- **Production Ready**: Pre-configured with persistence, NodePort service, and custom SANs
- **Flexible Configuration**: Customizable storage classes, ports, and networking
- **Connection Secret Management**: Automatic kubeconfig extraction via Crossplane connection secrets
- **ProviderConfig Generation**: Creates ready-to-use Kubernetes and Helm ProviderConfigs
- **Stuttgart-Things Provider**: Uses custom Crossplane Helm Provider

## Architecture

### Connection Secret Flow
```
VCluster Pod → Creates Secret → Object observes Secret → Connection Secret → ProviderConfigs
```

1. **VCluster** creates kubeconfig secret in target cluster
2. **Object** observes the VCluster secret (management policy: Observe)
3. **Connection Secret** extracts kubeconfig and creates secret in crossplane-system
4. **ProviderConfigs** reference the connection secret for Kubernetes/Helm access

## Usage

### Generate and Apply VCluster Release

#### 1. Generate YAML Only (Preview)

```bash
# Only generate YAML for review (no apply)
cd xplane-vcluster && kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vlcuster-k3s-tink1",
      "version": "0.29.0",
      "clusterName": "k3s-tink1",
      "targetNamespace": "vcluster-k3s-tink2",
      "storageClass": "local-path",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32445,
      "extraSANs": [
        "test-k3s1.labul.sva.de",
        "10.31.103.23",
        "localhost"
      ],
      "serverUrl": "https://10.31.103.23:32445",
      "additionalSecrets": [
        {
          "name": "vc-vlcuster-k3s-tink1-crossplane",
          "namespace": "vcluster-k3s-tink2",
          "context": "vcluster-crossplane-context",
          "server": "https://10.31.103.23:32445"
        }
      ],
      "connectionSecret": {
        "name": "vcluster-k3s-tink2-connection",
        "namespace": "crossplane-system",
        "vclusterSecretName": "vc-vlcuster-k3s-tink1",
        "vclusterSecretNamespace": "vcluster-k3s-tink2"
      }
    }
  }
}' --format yaml | grep -A 1000 "^items:" | grep -v "^items:" | sed 's/^- /---\n/' | sed '1d'
```

#### 2. One-Step Deployment (Direct Apply)

```bash
# VCluster with connection secrets and ProviderConfigs - direct apply
cd xplane-vcluster && kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vlcuster-k3s-tink1",
      "version": "0.29.0",
      "clusterName": "k3s-tink1",
      "targetNamespace": "vcluster-k3s-tink2",
      "storageClass": "local-path",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32445,
      "extraSANs": [
        "test-k3s1.labul.sva.de",
        "10.31.103.23",
        "localhost"
      ],
      "serverUrl": "https://10.31.103.23:32445",
      "additionalSecrets": [
        {
          "name": "vc-vlcuster-k3s-tink1-crossplane",
          "namespace": "vcluster-k3s-tink2",
          "context": "vcluster-crossplane-context",
          "server": "https://10.31.103.23:32445"
        }
      ],
      "connectionSecret": {
        "name": "vcluster-k3s-tink2-connection",
        "namespace": "crossplane-system",
        "vclusterSecretName": "vc-vlcuster-k3s-tink1",
        "vclusterSecretNamespace": "vcluster-k3s-tink2"
      }
    }
  }
}' --format yaml | grep -A 1000 "^items:" | grep -v "^items:" | sed 's/^- /---\n/' | sed '1d' | kubectl apply -f -
```

#### 3. Generate to File and Apply Separately

```bash
# Generate all resources to file
cd xplane-vcluster && kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vlcuster-k3s-tink1",
      "version": "0.29.0",
      "clusterName": "k3s-tink1",
      "targetNamespace": "vcluster-k3s-tink2",
      "storageClass": "local-path",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32445,
      "extraSANs": [
        "test-k3s1.labul.sva.de",
        "10.31.103.23",
        "localhost"
      ],
      "serverUrl": "https://10.31.103.23:32445",
      "additionalSecrets": [
        {
          "name": "vc-vlcuster-k3s-tink1-crossplane",
          "namespace": "vcluster-k3s-tink2",
          "context": "vcluster-crossplane-context",
          "server": "https://10.31.103.23:32445"
        }
      ],
      "connectionSecret": {
        "name": "vcluster-k3s-tink2-connection",
        "namespace": "crossplane-system",
        "vclusterSecretName": "vc-vlcuster-k3s-tink1",
        "vclusterSecretNamespace": "vcluster-k3s-tink2"
      }
    }
  }
}' --format yaml | grep -A 1000 "^items:" | grep -v "^items:" | sed 's/^- /---\n/' | sed '1d' > vcluster-k3s-tink2.yaml

# Review the generated file
cat vcluster-k3s-tink2.yaml

# Apply to cluster
kubectl apply -f vcluster-k3s-tink2.yaml
```

#### 3. Monitor Deployment

```bash
# Watch the helm release
kubectl get releases vlcuster-k3s-tink1 -w

# Check VCluster pods
kubectl get pods -n vcluster-k3s-tink2

# Verify connection secret was created
kubectl get secret vcluster-k3s-tink2-connection -n crossplane-system

# Check ProviderConfigs are ready
kubectl get providerconfig vlcuster-k3s-tink1
kubectl get providerconfig vlcuster-k3s-tink1-helm
```

#### 4. Extract and Test VCluster Kubeconfig

```bash
# Extract kubeconfig from connection secret
kubectl -n crossplane-system get secret vcluster-k3s-tink2-connection -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/vcluster-kubeconfig.yaml

# Alternative: Direct to named file
kubectl -n crossplane-system get secret vcluster-k3s-tink2-connection -o jsonpath='{.data.kubeconfig}' | base64 -d > vcluster-k3s-tink2-kubeconfig.yaml

# Test VCluster connectivity
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl get nodes
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl cluster-info

# Test with named file
KUBECONFIG=vcluster-k3s-tink2-kubeconfig.yaml kubectl get nodes
KUBECONFIG=vcluster-k3s-tink2-kubeconfig.yaml kubectl get namespaces

# Create test resources in VCluster
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl create namespace test-vcluster
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl run test-pod --image=nginx:alpine -n test-vcluster

# Verify test resources
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl get pods -n test-vcluster
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl get namespaces

# Test NodePort access (if accessible from your machine)
curl -k https://10.31.103.23:32445/api/v1/namespaces
```

#### 5. Cleanup Test Resources

```bash
# Remove test resources from VCluster
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl delete pod test-pod -n test-vcluster
KUBECONFIG=/tmp/vcluster-kubeconfig.yaml kubectl delete namespace test-vcluster

# Clean up kubeconfig files
rm /tmp/vcluster-kubeconfig.yaml vcluster-k3s-tink2-kubeconfig.yaml
```

## Generated Resources

The module creates the following Crossplane resources:

### 1. Helm Release
```yaml
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: vlcuster-k3s-tink1
spec:
  deletionPolicy: Delete
  forProvider:
    chart:
      name: vcluster
      repository: https://charts.loft.sh
      version: '0.29.0'
    namespace: vcluster-k3s-tink2
    values:
      controlPlane:
        # ... VCluster configuration
      exportKubeConfig:
        server: https://10.31.103.23:32445
        additionalSecrets:
          - name: vc-vlcuster-k3s-tink1-crossplane
            namespace: vcluster-k3s-tink2
  managementPolicies: ["*"]
  providerConfigRef:
    name: k3s-tink1
```

### 2. Connection Secret Object
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: vcluster-kubeconfig-reader
spec:
  deletionPolicy: Delete
  managementPolicies: ["Observe"]  # Important: Only observe!
  providerConfigRef:
    name: k3s-tink1
  forProvider:
    manifest:
      apiVersion: v1
      kind: Secret
      metadata:
        name: vc-vlcuster-k3s-tink1
        namespace: vcluster-k3s-tink2
  connectionDetails:
    - apiVersion: v1
      kind: Secret
      name: vc-vlcuster-k3s-tink1
      namespace: vcluster-k3s-tink2
      fieldPath: data.config
      toConnectionSecretKey: kubeconfig
  writeConnectionSecretToRef:
    name: vcluster-k3s-tink2-connection
    namespace: crossplane-system
```

### 3. Kubernetes ProviderConfig
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: vlcuster-k3s-tink1
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: vcluster-k3s-tink2-connection
      key: kubeconfig
```

### 4. Helm ProviderConfig
```yaml
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: vlcuster-k3s-tink1-helm
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: vcluster-k3s-tink2-connection
      key: kubeconfig
```

## Parameters

### Basic Parameters
- `name`: VCluster release name (required)
- `version`: VCluster chart version (default: "0.29.0")
- `chartName`: Helm chart name (default: "vcluster")
- `repository`: Helm repository URL (default: "https://charts.loft.sh")
- `clusterName`: Crossplane provider config reference (default: "kind")
- `targetNamespace`: Target namespace (default: "vcluster")

### VCluster Configuration
- `storageClass`: Storage class for persistence (default: "standard")
- `bindAddress`: Proxy bind address (default: "0.0.0.0")
- `proxyPort`: Internal proxy port (default: 8443)
- `nodePort`: External NodePort (default: 32443)
- `extraSANs`: Additional Subject Alternative Names (default: ["localhost"])
- `serverUrl`: External server URL for kubeconfig (default: "https://localhost:32443")
- `values`: Additional custom Helm values (default: {})

### Additional Secrets Configuration
- `additionalSecrets`: List of additional kubeconfig secrets to create (default: [])
  - `name`: Name of the additional secret
  - `namespace`: Namespace for the secret (optional, defaults to targetNamespace)
  - `context`: Custom context name for the kubeconfig (optional)
  - `server`: Custom server URL for the kubeconfig (optional)

### Connection Secret Configuration
- `connectionSecret.enabled`: Enable connection secret creation (default: true)
- `connectionSecret.name`: Name of the connection secret (default: "{name}-connection")
- `connectionSecret.namespace`: Namespace for connection secret (default: "crossplane-system")
- `connectionSecret.vclusterSecretName`: VCluster secret name to observe (default: "vc-{name}")
- `connectionSecret.vclusterSecretNamespace`: VCluster secret namespace (default: targetNamespace)

## Using the ProviderConfigs

Once deployed, you can use the generated ProviderConfigs to deploy resources to the VCluster:

### Kubernetes Resources
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: vcluster-test-configmap
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: test-configmap
        namespace: default
      data:
        message: "Hello from VCluster via Crossplane!"
  providerConfigRef:
    name: vlcuster-k3s-tink1  # References the generated ProviderConfig
```

### Helm Releases in VCluster
```yaml
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: nginx-in-vcluster
spec:
  forProvider:
    chart:
      name: nginx
      repository: https://charts.bitnami.com/bitnami
      version: "15.14.2"
    namespace: default
  providerConfigRef:
    name: vlcuster-k3s-tink1-helm  # References the generated Helm ProviderConfig
```

## Prerequisites

### Required Tools
- **KCL**: `curl -fsSL https://kcl-lang.io/script/install-cli.sh | bash`
- **kubectl**: Configured with Crossplane cluster access

### Crossplane Setup
Your cluster must have:
1. **Crossplane installed**: `helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace`
2. **Helm Provider installed**: Stuttgart-Things provider
3. **Kubernetes Provider installed**: For connection secrets
4. **Provider Configurations**: Configured for target cluster

```yaml
# Install Providers
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: ghcr.io/stuttgart-things/crossplane-provider-helm:0.1.1
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.18.0
```

## Dependencies

- Stuttgart-Things Crossplane Helm Provider: `ghcr.io/stuttgart-things/crossplane-provider-helm:0.1.1`
- Crossplane Kubernetes Provider: `xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.18.0`
- VCluster Helm Chart: `https://charts.loft.sh/vcluster`

## Examples

### VCluster

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vlcuster-k3s-tink1",
      "version": "0.29.0",
      "clusterName": "k3s-tink1",
      "targetNamespace": "vcluster-k3s-tink2",
      "storageClass": "local-path",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32445,
      "extraSANs": [
        "test-k3s1.labul.sva.de",
        "10.31.103.23",
        "localhost"
      ],
      "serverUrl": "https://10.31.103.23:32445",
      "additionalSecrets": [
        {
          "name": "vc-vlcuster-k3s-tink1-crossplane",
          "namespace": "vcluster-k3s-tink2",
          "context": "vcluster-crossplane-context",
          "server": "https://10.31.103.23:32445"
        }
      ],
      "connectionSecret": {
        "name": "vcluster-k3s-tink2-connection",
        "namespace": "crossplane-system",
        "vclusterSecretName": "vc-vlcuster-k3s-tink1",
        "vclusterSecretNamespace": "vcluster-k3s-tink2"
      }
    }
  }
}' --format yaml | grep -A 1000 "^items:" | grep -v "^items:" | sed 's/^- /---\n/' | sed '1d' | - kubectl apply -f
```

## Troubleshooting

### Common Issues

#### 1. Connection Secret Not Created
```bash
# Check if Object is synced
kubectl get object vcluster-kubeconfig-reader
kubectl describe object vcluster-kubeconfig-reader

# Check if VCluster secret exists
kubectl get secret vc-vlcuster-k3s-tink1 -n vcluster-k3s-tink1

# Check connection secret
kubectl get secret vlcuster-k3s-tink1-connection -n crossplane-system
```

#### 2. ProviderConfig Issues
```bash
# Check ProviderConfig status
kubectl get providerconfig vlcuster-k3s-tink1
kubectl describe providerconfig vlcuster-k3s-tink1

# Test connectivity
kubectl get nodes --kubeconfig=<(kubectl get secret vlcuster-k3s-tink1-connection -n crossplane-system -o jsonpath='{.data.kubeconfig}' | base64 -d)
```

### 3. Release Status
```bash
# Check Helm release status
kubectl get release vlcuster-k3s-tink1
kubectl describe release vlcuster-k3s-tink1

# Check VCluster pods
kubectl get pods -n vcluster-k3s-tink1
```

## Migration from Observe Pattern

If you're migrating from the old observe pattern:

1. **Remove old observe objects**
2. **Apply new connection secret configuration**
3. **Update ProviderConfig references** to use connection secrets
4. **Test connectivity** with new ProviderConfigs

The new approach is more reliable and follows Crossplane best practices for secret management.

## Container-Use Commands

To access your work from this container environment:

```bash
# View logs and changes
container-use log verified-alpaca

# Checkout the code
container-use checkout verified-alpaca

# View differences
container-use diff verified-alpaca
```