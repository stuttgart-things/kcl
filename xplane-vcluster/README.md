# Crossplane VCluster KCL Module

This KCL module creates a Crossplane Helm Release for deploying VCluster with production-ready configuration.

## Features

- **VCluster Deployment**: Creates VCluster instances via Crossplane Helm Provider
- **Production Ready**: Pre-configured with persistence, NodePort service, and custom SANs
- **Flexible Configuration**: Customizable storage classes, ports, and networking
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

# Get VCluster kubeconfig (after deployment)
vcluster connect my-vcluster -n vcluster-my-vcluster
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

Creates a `helm.crossplane.io/v1beta1/Release` resource for VCluster deployment through Crossplane.

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

## Cross-Cluster Secret Access

### Accessing VCluster Kubeconfig from Management Cluster

VCluster kubeconfig secrets remain in the target cluster by design. To access them from your Crossplane management cluster, use the "Observe" pattern:

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
