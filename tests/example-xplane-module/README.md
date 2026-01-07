# Crossplane-Compatible Deployment Module

This KCL module creates a Kubernetes Deployment that is compatible with both Crossplane Compositions and local rendering.

## Files

- `kcl.mod` - Module metadata
- `main.k` - KCL module (Deployment + Crossplane wrapper)
- `CROSSPLANE-DEPLOYMENT.md` - Detailed documentation

## Features

- **Crossplane Compatible**: Works with Crossplane XRDs, Compositions, and Function pipelines
- **Local Rendering**: Can render standalone for testing and direct kubectl apply
- **Easy Kubernetes Resource**: Creates a complete Deployment with sensible defaults
- **Flexible Parameters**: Supports both direct option passing and Composition parameter format

## Usage Examples

### 1. Direct Mode (Standalone - Local Rendering)

Render a deployment directly:

```bash
kcl run main.k \
  -D deploymentName="my-app" \
  -D namespace="production" \
  -D image="nginx:1.21" \
  -D replicas=3 \
  -D port=8080
```

### 2. Render and Apply to Cluster

```bash
kcl run main.k \
  -D deploymentName="my-app" \
  -D namespace="production" \
  -D image="myapp:v1.0" | kubectl apply -f -
```

### 3. Composition Mode (Crossplane Pipeline)

When used in a Crossplane Composition, the module receives parameters in this format:

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "deploymentName": "my-app",
      "namespace": "production",
      "image": "myapp:v1.0",
      "replicas": 3,
      "port": 8080
    }
  }
}'
```

Output: `items` array containing the Crossplane Object resource

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `deploymentName` | string | "hello-app" | Name of the deployment |
| `namespace` | string | "default" | Kubernetes namespace |
| `image` | string | "nginx:latest" | Container image URI |
| `replicas` | int | 1 | Number of replicas |
| `port` | int | 80 | Container port |
| `providerConfig` | string | "kubernetes-provider" | Crossplane provider config name |

## Sample Crossplane XRD

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdeployments.example.io
spec:
  group: example.io
  names:
    kind: XDeployment
    plural: xdeployments
  claimNames:
    kind: Deployment
    plural: deployments
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              deploymentName:
                type: string
              namespace:
                type: string
              image:
                type: string
              replicas:
                type: integer
              port:
                type: integer
```

## Sample Crossplane Composition

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: deployment-kcl
spec:
  compositeTypeRef:
    apiVersion: example.io/v1alpha1
    kind: XDeployment
  mode: Pipeline
  pipeline:
  - step: render-kcl
    functionRef:
      name: function-kcl
    input:
      apiVersion: krm.kcl.dev/v1alpha1
      kind: KCLRun
      spec:
        source: oci://your-registry/kcl-modules:deployment-v1
```

## Testing

```bash
# Test with defaults
kcl run main.k

# Test with custom values
kcl run main.k \
  -D deploymentName="test-app" \
  -D image="busybox:latest" \
  -D replicas=2

# Render as YAML for inspection
kcl run main.k -D deploymentName="test" -o yaml
```
