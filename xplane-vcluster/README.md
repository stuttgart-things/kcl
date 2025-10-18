# Crossplane VCluster KCL Module

This KCL module creates a Crossplane Helm Release for deploying VCluster with production-ready configuration.

## Features

- **VCluster Deployment**: Creates VCluster instances via Crossplane Helm Provider
- **Production Ready**: Pre-configured with persistence, NodePort service, and custom SANs
- **Flexible Configuration**: Customizable storage classes, ports, and networking
- **Cross-Cluster Secret Access**: Optional observe pattern for accessing VCluster secrets from management cluster
- **Stuttgart-Things Provider**: Uses custom Crossplane Helm Provider

## Usage

### Generate and Apply VCluster Release

#### 1. Generate YAML for Crossplane

```bash
# Basic VCluster Release
kcl run main.k -D params='{"oxr":{"spec":{"name":"my-vcluster"}}}' | yq '.items[]' > my-vcluster.yaml

# Production VCluster with Custom Configuration
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "xplane-test",
      "version": "0.29.0",
      "clusterName": "in-cluster",
      "targetNamespace": "vcluster-xplane-test",
      "storageClass": "standard",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32444,
      "extraSANs": [
        "maverick.tiab.labda.sva.de",
        "10.100.136.150",
        "localhost"
      ],
      "serverUrl": "https://10.100.136.150:32444"
    }
  }
}' | yq '.items[]' > xplane-test.yaml

# VCluster with Cross-Cluster Secret Observation
kcl run main.k --format yaml -D params='{
  "oxr": {
    "spec": {
      "name": "xplane-test",
      "version": "0.29.0",
      "clusterName": "in-cluster",
      "targetNamespace": "vcluster-xplane-test",
      "storageClass": "standard",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32444,
      "extraSANs": [
        "maverick.tiab.labda.sva.de",
        "10.100.136.150",
        "localhost"
      ],
      "serverUrl": "https://10.100.136.150:32444",
      "observeSecret": {
        "enabled": true,
        "clusterName": "k3s-tink1",
        "secretName": "vc-xplane-test", # pragma: allowlist secret
        "secretNamespace": "vcluster-xplane-test" # pragma: allowlist secret
      }
    }
  }
}' | yq '.items[]' | sed 's/^/---\n/;1s/^---//' #| > xplane-test-with-observer.yaml
```

#### 1.1. One-Step Render and Apply

For direct deployment without intermediate files:

```bash
# VCluster with local-path storage, additionalSecrets, and cross-cluster observation
cd xplane-vcluster && kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vlcuster-k3s-tink1",
      "version": "0.29.0",
      "clusterName": "k3s-tink1",
      "targetNamespace": "vcluster-k3s-tink1",
      "storageClass": "local-path",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32444,
      "extraSANs": [
        "test-k3s1.labul.sva.de",
        "10.31.103.23",
        "localhost"
      ],
      "serverUrl": "https://10.31.103.23:32444",
      "additionalSecrets": [
        {
          "name": "vc-vlcuster-k3s-tink1-crossplane",
          "namespace": "vcluster-k3s-tink1",
          "context": "vcluster-crossplane-context",
          "server": "https://10.31.103.23:32444"
        }
      ],
      "observeSecret": {
        "enabled": true,
        "clusterName": "k3s-tink1",
        "secretName": "vc-vlcuster-k3s-tink1", # pragma: allowlist secret
        "secretNamespace": "vcluster-k3s-tink1" # pragma: allowlist secret
      }
    }
  }
}' | yq '.items[]' > dev-vcluster.yaml


| kubectl apply -f -
```

#### 2. Apply to Crossplane Cluster

```bash
# Set your Crossplane cluster context
export KUBECONFIG=~/.kube/your-crossplane-cluster

# Apply the generated release
kubectl apply -f my-vcluster.yaml

# Check the release status
kubectl get releases
kubectl describe release my-vcluster
```

#### 3. Monitor VCluster Deployment

```bash
# Watch the helm release
kubectl get releases -w

# Check the VCluster pods (use actual namespace)
kubectl get pods -n vcluster-my-vcluster

# Check VCluster release status
kubectl get release my-vcluster -o yaml

# Traditional VCluster CLI method
vcluster connect my-vcluster -n vcluster-my-vcluster
```

#### 4. Extract Kubeconfig via Observe Pattern

When using `observeSecret.enabled: true`, extract the kubeconfig from the management cluster:

```bash
# Check if observe object is ready
kubectl get object vlcuster-k3s-tink1-secret-observer

# Extract kubeconfig from observed secret
kubectl get object vlcuster-k3s-tink1-secret-observer -o jsonpath='{.status.atProvider.manifest.data.config}' | base64 -d > vlcuster-k3s-tink1-kubeconfig.yaml

# Test VCluster connectivity
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl get nodes

# Create test resources in VCluster
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl create namespace test-vcluster
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl run test-pod --image=nginx:alpine -n test-vcluster

# Verify test pod
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl get pods -n test-vcluster
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

### Observe Secret Configuration
- `observeSecret.enabled`: Enable cross-cluster secret observation (default: false)
- `observeSecret.clusterName`: Target cluster provider config for secret observation (default: same as clusterName)
- `observeSecret.secretName`: Name of the VCluster secret to observe (default: "vc-{name}-kubeconfig")
- `observeSecret.secretNamespace`: Namespace of the VCluster secret to observe (default: same as targetNamespace)

## Generated Configuration

The module creates a VCluster with:

### Control Plane Configuration
```yaml
controlPlane:
  statefulSet:
    persistence:
      volumeClaim:
        storageClass: standard
  distro:
    k8s:
      enabled: true
  proxy:
    bindAddress: "0.0.0.0"
    port: 8443
    extraSANs:
      - "localhost"
  service:
    enabled: true
    spec:
      type: NodePort
      ports:
        - name: https
          port: 443
          targetPort: 8443
          nodePort: 32443
          protocol: TCP
```

### Export Configuration
```yaml
exportKubeConfig:
  server: "https://localhost:32443"
```

## Output

Creates the following Crossplane resources:

1. **`helm.crossplane.io/v1beta1/Release`** - VCluster deployment via Helm
2. **`kubernetes.crossplane.io/v1alpha2/Object`** - Secret observer (optional, when `observeSecret.enabled=true`)

The observe object allows access to VCluster kubeconfig secrets from the management cluster without manual secret copying.

## Prerequisites

### Required Tools
- **KCL**: `curl -fsSL https://kcl-lang.io/script/install-cli.sh | bash`
- **yq**: `https://github.com/mikefarah/yq#install`
- **kubectl**: Configured with Crossplane cluster access

### Crossplane Setup
Your cluster must have:
1. **Crossplane installed**: `helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace`
2. **Helm Provider installed**: `kubectl apply -f provider-helm.yaml`
3. **Provider Configuration**: Configured Helm provider for target cluster

```yaml
# provider-helm.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: ghcr.io/stuttgart-things/crossplane-provider-helm:0.1.1
```

## Dependencies

- Stuttgart-Things Crossplane Helm Provider: `ghcr.io/stuttgart-things/crossplane-provider-helm:0.1.1`
- Crossplane Kubernetes Provider: `crossplane-provider-kubernetes:0.18.0` (for observe functionality)
- VCluster Helm Chart: `https://charts.loft.sh/vcluster`

## Examples

### Development Environment
```bash
# Generate minimal development VCluster
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "dev-vcluster",
      "storageClass": "local-path"
    }
  }
}' | yq '.items[]' > dev-vcluster.yaml

```bash
# Apply to cluster
kubectl apply -f dev-vcluster.yaml

# Monitor deployment
kubectl get releases dev-vcluster -w
```
```

### Production Environment
```bash
# Generate full production VCluster
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "prod-vcluster",
      "version": "0.29.0",
      "clusterName": "production-cluster",
      "storageClass": "fast-ssd",
      "extraSANs": [
        "vcluster.company.com",
        "10.0.0.100"
      ],
      "serverUrl": "https://vcluster.company.com:32443"
    }
  }
}' | yq '.items[]' > prod-vcluster.yaml

# Apply to production cluster
export KUBECONFIG=~/.kube/production-cluster
kubectl apply -f prod-vcluster.yaml
```

### Batch Generation
```bash
# Generate multiple VCluster configurations
for env in dev staging prod; do
  kcl run main.k -D params="{\"oxr\":{\"spec\":{\"name\":\"${env}-vcluster\",\"clusterName\":\"${env}-cluster\"}}}" | yq '.items[]' > ${env}-vcluster.yaml
done

# Apply all at once
kubectl apply -f dev-vcluster.yaml -f staging-vcluster.yaml -f prod-vcluster.yaml
```

### VCluster with Secret Observation
```bash
# Generate VCluster with automatic secret observation
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "monitored-vcluster",
      "clusterName": "management-cluster",
      "targetNamespace": "vcluster-ns",
      "observeSecret": {
        "enabled": true,
        "clusterName": "remote-k3s",
        "secretName": "vc-monitored-vcluster", # pragma: allowlist secret
        "secretNamespace": "vcluster-ns" # pragma: allowlist secret
      }
    }
  }
}' | yq '.items[]' > monitored-vcluster.yaml

# Apply both VCluster and observer
kubectl apply -f monitored-vcluster.yaml

# Extract kubeconfig from observed secret
kubectl get object monitored-vcluster-secret-observer -o jsonpath='{.status.atProvider.manifest.data.config}' | base64 -d > monitored-vcluster-kubeconfig.yaml
```

### Complete Local-Path VCluster Testing Workflow

```bash
# 1. Deploy VCluster with local-path storage and observe pattern
cd xplane-vcluster && kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vlcuster-k3s-tink1",
      "version": "0.29.0",
      "clusterName": "k3s-tink1",
      "targetNamespace": "vcluster-k3s-tink1",
      "storageClass": "local-path",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32444,
      "extraSANs": [
        "test-k3s1.labul.sva.de",
        "10.31.103.23",
        "localhost"
      ],
      "serverUrl": "https://10.31.103.23:32444",
      "additionalSecrets": [
        {
          "name": "vc-vlcuster-k3s-tink1-crossplane",
          "namespace": "default",
          "context": "vcluster-crossplane-context",
          "server": "https://10.31.103.23:32444"
        }
      ],
      "observeSecret": {
        "enabled": true,
        "clusterName": "k3s-tink1",
        "secretName": "vc-vlcuster-k3s-tink1", # pragma: allowlist secret
        "secretNamespace": "vcluster-k3s-tink1" # pragma: allowlist secret
      }
    }
  }
}' | yq '.items[]' | kubectl apply -f -

# 2. Monitor deployment progress
kubectl get releases vlcuster-k3s-tink1 -w

# 3. Check observe object status
kubectl get object vlcuster-k3s-tink1-secret-observer

# 4. Extract kubeconfig when ready
kubectl get object vlcuster-k3s-tink1-secret-observer -o jsonpath='{.status.atProvider.manifest.data.config}' | base64 -d > vlcuster-k3s-tink1-kubeconfig.yaml

# 5. Test VCluster connectivity
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl get nodes

# 6. Create test namespace and pod
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl create namespace test-vcluster
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl run test-pod --image=nginx:alpine -n test-vcluster

# 7. Verify deployment
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl get pods -n test-vcluster -w
```

## Cross-Cluster Secret Access

### Accessing VCluster Kubeconfig from Management Cluster

VCluster kubeconfig secrets remain in the target cluster by design. To access them from your Crossplane management cluster, use the "Observe" pattern:

### Creating ProviderConfig for VCluster

Once you have the observed secret, create a ProviderConfig to use the VCluster from Crossplane:

VCluster can create properly formatted kubeconfig secrets directly using `additionalSecrets`. This eliminates the need for manual extraction scripts:

```yaml
# vcluster-provider-config.yaml
# ProviderConfigs using VCluster additionalSecrets (no manual extraction needed)
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: vcluster-k3s-tink1
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: default
      name: vc-vlcuster-k3s-tink1-crossplane  # Created by VCluster additionalSecrets
      key: config
---
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: vcluster-k3s-tink1-helm
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: default
      name: vc-vlcuster-k3s-tink1-crossplane  # Created by VCluster additionalSecrets
      key: config
```

```bash
# Step 1: Deploy VCluster with additionalSecrets (creates the secret automatically)
# Step 2: Apply the ProviderConfig
kubectl apply -f vcluster-provider-config.yaml

# Step 3: Verify ProviderConfig is ready
kubectl get providerconfig vcluster-k3s-tink1
kubectl get providerconfig vcluster-k3s-tink1-helm

# Now you can use the VCluster as a target for Crossplane resources
# Example: Deploy resources to the VCluster using providerConfigRef: "vcluster-k3s-tink1"
```

#### Using the VCluster ProviderConfig

Deploy Kubernetes resources to the VCluster using the Kubernetes Provider:

```yaml
# Example: Deploy ConfigMap to VCluster
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
        cluster: "vcluster-k3s-tink1"
  providerConfigRef:
    name: vcluster-k3s-tink1  # References the VCluster ProviderConfig

# Example: Create Namespace in VCluster
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: vcluster-test-namespace
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: crossplane-deployed
        labels:
          managed-by: crossplane
          target-cluster: vcluster
  providerConfigRef:
    name: vcluster-k3s-tink1  # References the VCluster ProviderConfig
```

```bash
# Apply example resources to VCluster
kubectl apply -f vcluster-kubernetes-example.yaml

# Verify resources were created in VCluster
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl get configmap test-configmap
KUBECONFIG=vlcuster-k3s-tink1-kubeconfig.yaml kubectl get namespace crossplane-deployed
```

#### Complete Working Example

```bash
# 1. Deploy VCluster with additionalSecrets (no manual extraction needed)
# The VCluster automatically creates the properly formatted secret

# 2. Apply ProviderConfigs (uses the automatically created secret)
kubectl apply -f vcluster-provider-config.yaml

# 3. Deploy test resources to VCluster
kubectl apply -f vcluster-kubernetes-example.yaml

# 4. Verify Crossplane objects are synced and ready
kubectl get object vcluster-test-configmap vcluster-test-namespace
# Expected output:
# NAME                      KIND        PROVIDERCONFIG       SYNCED   READY   AGE
# vcluster-test-configmap   ConfigMap   vcluster-k3s-tink1   True     True    30s
# vcluster-test-namespace   Namespace   vcluster-k3s-tink1   True     True    30s

# 5. Verify the automatically created secret exists
kubectl get secret vc-vlcuster-k3s-tink1-crossplane -n default
```

#### 1. Create Observe Object

```yaml
# observe-vcluster-secret.yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: vc-test-vcluster-localpath-secret
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: Secret
      metadata:
        name: vc-test-vcluster-localpath
        namespace: vcluster-test
  managementPolicies: ["Observe"]
  providerConfigRef:
    name: k3s-tink1  # Reference to your target cluster provider config
```

#### 2. Apply and Extract Kubeconfig

```bash
# Apply the observe object
kubectl apply -f observe-vcluster-secret.yaml

# Extract the kubeconfig
kubectl get object vc-test-vcluster-localpath-secret -o jsonpath='{.status.atProvider.manifest.data.config}' | base64 -d > vcluster-kubeconfig.yaml

# Use the VCluster
KUBECONFIG=vcluster-kubeconfig.yaml kubectl get nodes
```

#### 3. Prerequisites for Observe Pattern

- **Kubernetes Provider**: Must be installed in management cluster
- **Provider Config**: Target cluster must be configured as provider config
- **RBAC**: Crossplane must have permissions to read secrets in target cluster

```bash
# Install Kubernetes Provider
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.0
EOF
```

## Troubleshooting

### Common Issues

#### 1. CRD Not Found Error
```bash
# Error: no matches for kind "Release" in version "helm.crossplane.io/v1beta1"
# Solution: Install Crossplane Helm Provider
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: ghcr.io/stuttgart-things/crossplane-provider-helm:0.1.1
EOF

# Wait for provider to be ready
kubectl wait --for=condition=Healthy provider/provider-helm --timeout=300s
```

#### 2. Provider Configuration Missing
```bash
# Check if provider config exists
kubectl get providerconfigs

# Create provider config if missing
kubectl apply -f - <<EOF
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: in-cluster
spec:
  credentials:
    source: InjectedIdentity
EOF
```

#### 3. Validate Generated YAML
```bash
# Check the generated YAML before applying
kcl run main.k -D params='{"oxr":{"spec":{"name":"test"}}}' | yq '.items[]' | kubectl --dry-run=client -f -

# Validate with server-side dry run
kubectl apply --dry-run=server -f your-vcluster.yaml
```

#### 4. Monitor Release Status
```bash
# Check release status
kubectl get releases -o wide

# Check release events
kubectl describe release your-vcluster-name

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-helm
```

#### 5. ProviderConfig Issues

```bash
# Verify the additionalSecret was created by VCluster
kubectl get secret vc-vlcuster-k3s-tink1-crossplane -n default

# Check if the secret has the correct format
kubectl get secret vc-vlcuster-k3s-tink1-crossplane -n default -o jsonpath='{.data.config}' | base64 -d | head -5

# Verify ProviderConfig status
kubectl get providerconfigs.kubernetes.crossplane.io vcluster-k3s-tink1
kubectl describe providerconfigs.kubernetes.crossplane.io vcluster-k3s-tink1

# Test Object status
kubectl get object vcluster-test-configmap -o yaml
kubectl describe object vcluster-test-configmap

# Check VCluster release status
kubectl get release vlcuster-k3s-tink1 -o yaml
```
