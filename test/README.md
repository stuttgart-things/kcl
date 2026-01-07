# KCL Test Module: Crossplane-Compatible Deployment

A production-ready KCL module for creating Kubernetes Deployments that works both standalone and with Crossplane Compositions.

## Files

- `kcl.mod` - Module metadata
- `crossplane-deployment.k` - Main KCL module (Deployment + Crossplane wrapper)
- `CROSSPLANE-DEPLOYMENT.md` - Detailed documentation

## Quick Start

### Local Rendering
```bash
kcl run crossplane-deployment.k \
  -D deploymentName="my-app" \
  -D image="nginx:latest" \
  -D replicas=3
```

### Apply to Cluster
```bash
kcl run crossplane-deployment.k -D deploymentName="my-app" | kubectl apply -f -
```

### With Crossplane Composition
```bash
kcl run crossplane-deployment.k -D params='{
  "oxr": {
    "spec": {
      "deploymentName": "my-app",
      "image": "nginx:latest",
      "replicas": 3
    }
  }
}'
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `deploymentName` | "hello-app" | Deployment name |
| `namespace` | "default" | K8s namespace |
| `image` | "nginx:latest" | Container image |
| `replicas` | 1 | Pod replicas |
| `port` | 80 | Container port |
| `providerConfig` | "kubernetes-provider" | Crossplane provider |

See [CROSSPLANE-DEPLOYMENT.md](./CROSSPLANE-DEPLOYMENT.md) for full documentation.
