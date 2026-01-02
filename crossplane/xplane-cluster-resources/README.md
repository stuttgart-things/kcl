# Crossplane ProviderConfig KCL Module

This KCL module creates either a `ProviderConfig` or `ClusterProviderConfig` for Crossplane Helm or Kubernetes Providers with flexible configuration options.

## Features

- ✅ Support for **Helm** and **Kubernetes** providers
- ✅ Create `ProviderConfig` or `ClusterProviderConfig` (controlled by boolean)
- ✅ Conditional output control
- ✅ Two configuration styles: CLI arguments or XR params structure
- ✅ Schema validation with sensible defaults

## Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clusterName` | string | `"target"` | Name of the cluster/provider config |
| `credNamespace` | string | `"crossplane-system"` | Namespace where credentials secret is stored |
| `credSecretName` | string | `"target"` | Name of the secret containing kubeconfig |
| `credKey` | string | `"config"` | Key in the secret containing kubeconfig data |
| `providerType` | string | `"helm"` | Provider type: `"helm"` or `"kubernetes"` |
| `useClusterProviderConfig` | boolean | `false` | If true, creates `ClusterProviderConfig` instead of `ProviderConfig` |
| `createProviderConfig` | boolean | `true` | If false, excludes the config from output |

## Usage

### Style 1: Direct CLI Arguments

#### Helm ProviderConfig (Default)
```bash
kcl run main.k \
  -D clusterName="my-cluster" \
  -D credNamespace="crossplane-system" \
  -D credSecretName="dev" \
  -D credKey="config" \
  --format yaml | yq eval -P '.items[]' -
```

#### Kubernetes ProviderConfig
```bash
kcl run main.k \
  -D clusterName="kubernetes-provider" \
  -D credNamespace="crossplane-system" \
  -D credSecretName="cluster-config" \
  -D credKey="kubeconfig" \
  -D providerType="kubernetes" \
  --format yaml | yq eval -P '.items[]' -
```

#### Helm ClusterProviderConfig
```bash
kcl run main.k \
  -D clusterName="production-cluster" \
  -D credNamespace="crossplane-system" \
  -D credSecretName="prod-kubeconfig" \
  -D credKey="kubeconfig" \
  -D providerType="helm" \
  -D useClusterProviderConfig=true \
  --format yaml | yq eval -P '.items[]' -
```

#### Kubernetes ClusterProviderConfig
```bash
kcl run main.k \
  -D clusterName="kubernetes-provider" \
  -D credNamespace="crossplane-system" \
  -D credSecretName="cluster-config" \
  -D credKey="kubeconfig" \
  -D providerType="kubernetes" \
  -D useClusterProviderConfig=true \
  --format yaml | yq eval -P '.items[]' -
```

#### Disable Output (Empty Items Array)
```bash
kcl run main.k \
  -D clusterName="my-cluster" \
  -D createProviderConfig=false \
  --format yaml | yq eval -P '.items[]' -
```

### Style 2: XR Params Structure

#### Helm ProviderConfig
```bash
kcl run main.k \
  -D params='{"oxr":{"spec":{"clusterName":"my-cluster","credNamespace":"crossplane-system","credSecretName":"my-kubeconfig-secret","credKey":"kubeconfig","providerType":"helm"}}}' \
  --format yaml | yq eval -P '.items[]' -
```

#### Kubernetes ClusterProviderConfig
```bash
kcl run main.k \
  -D params='{"oxr":{"spec":{"clusterName":"kubernetes-provider","credNamespace":"crossplane-system","credSecretName":"cluster-config","credKey":"kubeconfig","providerType":"kubernetes","useClusterProviderConfig":true}}}' \
  --format yaml | yq eval -P '.items[]' -
```

#### Disable Output
```bash
kcl run main.k \
  -D params='{"oxr":{"spec":{"clusterName":"my-cluster","credNamespace":"crossplane-system","credSecretName":"my-kubeconfig-secret","credKey":"kubeconfig","createProviderConfig":false}}}' \
  --format yaml | yq eval -P '.items[]' -
```

### Style 3: Mixed (Params + CLI Override)

CLI arguments override params structure values:
```bash
kcl run main.k \
  -D params='{"oxr":{"spec":{"clusterName":"base-cluster","providerType":"helm"}}}' \
  -D credNamespace="override-namespace" \
  -D providerType="kubernetes" \
  -D useClusterProviderConfig=true \
  --format yaml | yq eval -P '.items[]' -
```

## Example Outputs

### Helm ProviderConfig
```yaml
apiVersion: helm.m.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: my-cluster
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: dev
      key: config
```

### Kubernetes ClusterProviderConfig
```yaml
apiVersion: kubernetes.m.crossplane.io/v1alpha1
kind: ClusterProviderConfig
metadata:
  name: kubernetes-provider
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: cluster-config
      key: kubeconfig
```

### Helm ClusterProviderConfig
```yaml
apiVersion: helm.m.crossplane.io/v1beta1
kind: ClusterProviderConfig
metadata:
  name: production-cluster
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: prod-kubeconfig
      key: kubeconfig
```

## Provider Types

| Provider Type | API Version | Use Case |
|--------------|-------------|----------|
| `helm` | `helm.m.crossplane.io/v1beta1` | Managing Helm releases via Crossplane |
| `kubernetes` | `kubernetes.m.crossplane.io/v1alpha1` | Managing Kubernetes resources via Crossplane |

## File Structure
```
.
├── main.k          # Main logic and resource creation
└── schema.k        # Schema definition with validation
```

## Crossplane Integration

This module is designed to work with Crossplane Composition Functions. Use in your Composition:
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: my-composition
spec:
  compositeTypeRef:
    apiVersion: example.io/v1alpha1
    kind: XCluster
  mode: Pipeline
  pipeline:
    - step: create-provider-configs
      functionRef:
        name: function-kcl
      input:
        apiVersion: krm.kcl.dev/v1alpha1
        kind: KCLInput
        spec:
          source: |
            # Your KCL code here
          params:
            oxr:
              spec:
                clusterName: ${context.spec.clusterName}
                providerType: "kubernetes"
                useClusterProviderConfig: true
```

## Notes

- CLI arguments (`-D key=value`) take precedence over params structure
- The `createProviderConfig` flag is useful when conditionally including resources in multi-resource modules
- Both `ProviderConfig` and `ClusterProviderConfig` require the secret to exist before the resource is created
- When `providerType` is not specified, it defaults to `"helm"`
- Invalid provider types will fallback to `"helm"`