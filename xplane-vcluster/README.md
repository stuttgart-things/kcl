# Crossplane VCluster KCL Module

This KCL module creates a Crossplane Helm Release for deploying VCluster with production-ready configuration.

## Features

- **VCluster Deployment**: Creates VCluster instances via Crossplane Helm Provider
- **Production Ready**: Pre-configured with persistence, NodePort service, and custom SANs
- **Flexible Configuration**: Customizable storage classes, ports, and networking
- **Stuttgart-Things Provider**: Uses custom Crossplane Helm Provider

## Usage

### Basic VCluster Deployment

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "my-vcluster"
    }
  }
}'
```

### Production VCluster with Custom Configuration

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "maverick-vcluster",
      "version": "0.29.0",
      "clusterName": "production-cluster",
      "targetNamespace": "vcluster",
      "storageClass": "fast-ssd",
      "bindAddress": "0.0.0.0",
      "proxyPort": 8443,
      "nodePort": 32443,
      "extraSANs": [
        "maverick.tiab.labda.sva.de",
        "10.100.136.150",
        "localhost"
      ],
      "serverUrl": "https://10.100.136.150:32443"
    }
  }
}'
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

## Dependencies

- Stuttgart-Things Crossplane Helm Provider: `ghcr.io/stuttgart-things/crossplane-provider-helm:0.1.1`
- VCluster Helm Chart: `https://charts.loft.sh/vcluster`

## Examples

### Development Environment
```bash
# Minimal setup for development
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "dev-vcluster",
      "storageClass": "local-path"
    }
  }
}'
```

### Production Environment
```bash
# Full production setup
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
}'
```