# Kubernetes Resources Module

Standalone KCL module for rendering basic Kubernetes resources (PersistentVolumeClaims, Secrets, ConfigMaps, Namespaces).

This module is **NOT** designed for Crossplane integration. It renders plain Kubernetes YAML for direct application to clusters.

## Quick Start

### PVC with -D parameters (fastest)

```bash
kcl run main.k \
  -D enablePvc=true \
  -D pvcName=my-storage \
  -D pvcSize=50Gi \
  --format yaml
```

### PVC with Harvester annotations and custom accessModes

```bash
kcl run main.k \
  -D enablePvc=true \
  -D pvcName=dev2-disk-0 \
  -D pvcVolumeMode=Block \
  -D pvcAccessModes=ReadWriteMany \
  -D pvcStorageClass=longhorn-image-t9w92 \
  -D 'pvcAnnotations={"harvesterhci.io/imageId":"default/image-t9w92"}' \
  --format yaml
```

### Multiple resources

```bash
kcl run main.k \
  -D enableNamespace=true -D namespaceName=myapp \
  -D enablePvc=true -D pvcName=data \
  -D enableSecret=true -D secretName=credentials \
  -D enableConfigMap=true -D configMapName=config \
  --format yaml
```

### Using config file

```bash
kcl run main.k config.kcl --format yaml
```

## Supported Resources

| Resource Type | Kind | Default Status | Enable Flag | Primary Parameters |
|---|---|---|---|---|
| Namespace | `Namespace` | Disabled | `-D enableNamespace=true` | `namespaceName`, `namespaceLabels`, `namespaceAnnotations` |
| PersistentVolumeClaim | `PersistentVolumeClaim` | Disabled | `-D enablePvc=true` | `pvcName`, `pvcSize`, `pvcStorageClass`, `pvcVolumeMode`, `pvcAccessModes` |
| Secret | `Secret` | Disabled | `-D enableSecret=true` | `secretName`, `secretType`, `secretNamespace`, `secretData` |
| ConfigMap | `ConfigMap` | Disabled | `-D enableConfigMap=true` | `configMapName`, `configMapNamespace`, `configMapData` |

## Key Principle: Explicit Enable Required

All resources are **disabled by default**. Each resource type must be explicitly enabled in the configuration file.

```kcl
# Resources are disabled by default - NOTHING is rendered
_pvc = {
    enabled = False  # Default
    # ... other config
}

# Enable explicitly to render
_secret = {
    enabled = True   # Must set to True
    name = "my-secret"
    # ... other config
}
```

## Features

- **Explicit Enable/Disable**: All resources disabled by default, must opt-in
- **Multiple Resource Types**: PVC, Secrets, ConfigMaps, Namespaces
- **Plain Kubernetes Output**: Renders native Kubernetes YAML (v1 API)
- **Flexible Configuration**: Labels, annotations, custom data
- **Type-Safe**: Schema validation for all resource types
- **Composable**: Render one or multiple resources in single output

## Resource Types

### PersistentVolumeClaim (PVC)

```kcl
_pvc = {
    enabled = True              # MUST be True to render
    name = "app-storage"
    namespace = "default"
    size = "10Gi"
    storageClass = "standard"
    volumeMode = "Filesystem"   # or "Block"
    accessModes = ["ReadWriteOnce"]  # or other modes
    labels = {key = "value"}
    annotations = {key = "value"}
}
```

### Secret

```kcl
_secret = {
    enabled = True
    name = "app-secret"
    namespace = "default"
    type = "Opaque"             # or "kubernetes.io/basic-auth", etc
    data = {
        username = "admin"
        password = "secret"
        api_key = "key123"
    }
    labels = {key = "value"}
    annotations = {key = "value"}
}
```

### ConfigMap

```kcl
_configMap = {
    enabled = True
    name = "app-config"
    namespace = "default"
    data = {
        ENVIRONMENT = "production"
        DEBUG = "false"
        MAX_WORKERS = "10"
    }
    binaryData = {}             # Optional binary data
    labels = {key = "value"}
    annotations = {key = "value"}
}
```

### Namespace

```kcl
_namespace = {
    enabled = True
    name = "my-namespace"
    labels = {
        environment = "production"
    }
    annotations = {key = "value"}
}
```

## Usage

### Basic: Single Resource with Config File

Create config file `config.kcl`:

```kcl
# Only enable PVC, other resources disabled (default)
_pvc = {
    enabled = True
    name = "my-pvc"
    namespace = "default"
    size = "20Gi"
}
```

Run:

```bash
kcl run main.k config.kcl --format yaml
```

### Using -D Parameters (Recommended)

Control resources directly via command-line without config files:

```bash
# PVC only
kcl run main.k \
  -D enablePvc=true \
  -D pvcName=my-storage \
  -D pvcSize=100Gi \
  -D pvcStorageClass=longhorn \
  --format yaml

# Secret only
kcl run main.k \
  -D enableSecret=true \
  -D secretName=db-credentials \
  -D secretNamespace=production \
  --format yaml

# Multiple resources
kcl run main.k \
  -D enableNamespace=true \
  -D namespaceName=myapp \
  -D enablePvc=true \
  -D pvcName=app-storage \
  -D pvcSize=50Gi \
  -D enableSecret=true \
  -D secretName=app-secret \
  -D enableConfigMap=true \
  -D configMapName=app-config \
  --format yaml
```

### Combining Config Files and -D Parameters

Config file `base.kcl`:

```kcl
_pvc = {
    enabled = True
    name = "default-pvc"
    size = "10Gi"
}
```

Override with -D parameters:

```bash
# Config file's defaults + -D overrides
kcl run main.k base.kcl \
  -D pvcName=custom-pvc \
  -D pvcSize=100Gi \
  --format yaml
```

### Multiple Resources

Create config file:

```kcl
_pvc = {
    enabled = True
    name = "postgres-data"
    namespace = "default"
    size = "100Gi"
    storageClass = "fast-ssd"
}

_secret = {
    enabled = True
    name = "db-credentials"
    namespace = "default"
    data = {
        username = "postgres"
        password = "secret123"
    }
}

_configMap = {
    enabled = True
    name = "db-config"
    namespace = "default"
    data = {
        POSTGRES_DB = "myapp"
        LOG_LEVEL = "info"
    }
}
```

Run:

```bash
kcl run main.k config.kcl --format yaml
```

Output (all three resources):

```yaml
items:
- apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: postgres-data
    namespace: default
  # ... PVC spec
- apiVersion: v1
  kind: Secret
  metadata:
    name: db-credentials
    namespace: default
  # ... Secret spec
- apiVersion: v1
  kind: ConfigMap
  metadata:
    name: db-config
    namespace: default
  # ... ConfigMap spec
```

## Examples Included

### 1. PVC Only (`examples/pvc-only.kcl`)

Single PVC with custom labels and storage class:

```bash
kcl run main.k examples/pvc-only.kcl --format yaml
```

### 2. Secret Only (`examples/secret-only.kcl`)

Single Secret with database credentials:

```bash
kcl run main.k examples/secret-only.kcl --format yaml
```

### 3. Multiple Resources (`examples/multi-resources.kcl`)

PostgreSQL stack: PVC + Secret + ConfigMap

```bash
kcl run main.k examples/multi-resources.kcl --format yaml
```

### 4. Full Stack (`examples/full-stack.kcl`)

Complete namespace with all resource types:

```bash
kcl run main.k examples/full-stack.kcl --format yaml
```

## Applying to Kubernetes

### With Config File

```bash
# Apply to cluster
kcl run main.k config.kcl --format yaml

# Dry-run
kcl run main.k config.kcl --format yaml  --dry-run=client

# Export to file
kcl run main.k config.kcl --format yaml > resources.yaml
kubectl apply -f resources.yaml
```

### With -D Parameters

```bash
# Apply directly
kcl run main.k \
  -D enablePvc=true \
  -D pvcName=app-storage \
  -D pvcSize=50Gi \
  --format yaml

# Dry-run
kcl run main.k \
  -D enablePvc=true \
  -D pvcName=app-storage \
  --format yaml  --dry-run=client

# Export to file
kcl run main.k \
  -D enablePvc=true \
  -D pvcName=app-storage \
  --format yaml > pvc.yaml
kubectl apply -f pvc.yaml
```

## Configuration Schema

### -D Parameters Reference

#### PVC Parameters

```bash
-D enablePvc=true|false            # Enable/disable PVC rendering
-D pvcName=<string>                # PVC name (default: pvc)
-D pvcNamespace=<string>           # Namespace (default: default)
-D pvcSize=<string>                # Storage size (default: 10Gi)
-D pvcStorageClass=<string>        # Storage class (default: standard)
-D pvcVolumeMode=<string>          # Filesystem or Block (default: Filesystem)
-D pvcAccessModes=<list>           # Access modes, comma-separated (default: ReadWriteOnce)
-D pvcLabels=<map>                 # Key=value labels (JSON format)
-D pvcAnnotations=<map>            # Key=value annotations (JSON format)
```

**pvcAccessModes** examples:
```bash
-D pvcAccessModes=ReadWriteMany           # Single mode
-D pvcAccessModes=ReadWriteOnce,ReadOnlyMany  # Multiple modes (comma-separated)
```

#### Secret Parameters

```bash
-D enableSecret=true|false       # Enable/disable Secret rendering
-D secretName=<string>           # Secret name (default: secret)
-D secretNamespace=<string>      # Namespace (default: default)
-D secretType=<string>           # Secret type (default: Opaque)
-D secretData=<map>              # Key=value data
-D secretLabels=<map>            # Key=value labels
-D secretAnnotations=<map>       # Key=value annotations
```

#### ConfigMap Parameters

```bash
-D enableConfigMap=true|false    # Enable/disable ConfigMap rendering
-D configMapName=<string>        # ConfigMap name (default: configmap)
-D configMapNamespace=<string>   # Namespace (default: default)
-D configMapData=<map>           # Key=value data
-D configMapBinaryData=<map>     # Key=value binary data
-D configMapLabels=<map>         # Key=value labels
-D configMapAnnotations=<map>    # Key=value annotations
```

#### Namespace Parameters

```bash
-D enableNamespace=true|false    # Enable/disable Namespace rendering
-D namespaceName=<string>        # Namespace name (default: default)
-D namespaceLabels=<map>         # Key=value labels
-D namespaceAnnotations=<map>    # Key=value annotations
```

### Config File Parameters

#### PvcConfig

| Field | Type | Default | Required |
|-------|------|---------|----------|
| `enabled` | bool | False | No |
| `name` | str | "pvc" | No |
| `namespace` | str | "default" | No |
| `size` | str | "10Gi" | No |
| `storageClass` | str | "standard" | No |
| `volumeMode` | str | "Filesystem" | No |
| `accessModes` | [str] | ["ReadWriteOnce"] | No |
| `labels` | {str:str} | {} | No |
| `annotations` | {str:str} | {} | No |

#### SecretConfig

| Field | Type | Default | Required |
|-------|------|---------|----------|
| `enabled` | bool | False | No |
| `name` | str | "secret" | No |
| `namespace` | str | "default" | No |
| `type` | str | "Opaque" | No |
| `data` | {str:str} | {} | No |
| `labels` | {str:str} | {} | No |
| `annotations` | {str:str} | {} | No |

#### ConfigMapConfig

| Field | Type | Default | Required |
|-------|------|---------|----------|
| `enabled` | bool | False | No |
| `name` | str | "configmap" | No |
| `namespace` | str | "default" | No |
| `data` | {str:str} | {} | No |
| `binaryData` | {str:str} | {} | No |
| `labels` | {str:str} | {} | No |
| `annotations` | {str:str} | {} | No |

#### NamespaceConfig

| Field | Type | Default | Required |
|-------|------|---------|----------|
| `enabled` | bool | False | No |
| `name` | str | "default" | No |
| `labels` | {str:str} | {} | No |
| `annotations` | {str:str} | {} | No |

## Design Principles

1. **Explicit Enable**: All resources disabled by default - must opt-in
2. **Plain Kubernetes**: Renders native Kubernetes API (no Crossplane wrappers)
3. **Type Safe**: Schema validation for all configurations
4. **Composable**: Support rendering one or multiple resources
5. **Flexible**: Support labels, annotations, custom data
6. **Simple**: Clear, predictable configuration structure

## Standalone vs. Crossplane

This module is for **standalone Kubernetes usage only**:

| Aspect | This Module | Crossplane Module |
|--------|------------|------------------|
| **Wrapper** | No (plain K8s) | Yes (kubernetes.crossplane.io/v1alpha2/Object) |
| **Provider** | Direct kubectl | Crossplane provider-kubernetes |
| **XR Integration** | Not applicable | Yes (option("params")?.oxr?.spec) |
| **Use Case** | Direct K8s manifests | Composition functions |
| **Output** | Native Kubernetes YAML | Crossplane Objects |

## Module Structure

```
.
├── kcl.mod                  # Module metadata
├── main.k                   # Resource schemas and generators
├── examples/
│   ├── pvc-only.kcl         # Single PVC example
│   ├── secret-only.kcl      # Single Secret example
│   ├── multi-resources.kcl  # Multiple resource types
│   └── full-stack.kcl       # Complete stack with namespace
└── README.md                # This file
```

## Testing

### Quick Tests with -D Parameters

```bash
# PVC only - Fast test
kcl run main.k \
  -D enablePvc=true \
  -D pvcName=test-pvc \
  --format yaml | grep "kind:"

# Secret only
kcl run main.k \
  -D enableSecret=true \
  -D secretName=test-secret \
  --format yaml | grep "kind:"

# Multiple resources
kcl run main.k \
  -D enablePvc=true \
  -D enableSecret=true \
  -D enableConfigMap=true \
  --format yaml | grep "kind:"

# Full stack with namespace
kcl run main.k \
  -D enableNamespace=true \
  -D namespaceName=test-ns \
  -D enablePvc=true \
  -D enableSecret=true \
  -D enableConfigMap=true \
  --format yaml | grep "kind:"
```

### Test Config Files

```bash
# PVC only
kcl run main.k examples/pvc-only.kcl --format yaml | grep "kind:" | head -1

# Secret only
kcl run main.k examples/secret-only.kcl --format yaml | grep "kind:" | head -1

# Multiple resources
kcl run main.k examples/multi-resources.kcl --format yaml | grep "kind:"

# Full stack
kcl run main.k examples/full-stack.kcl --format yaml | grep "kind:"
```

## Notes

- Resources render in order: Namespace → PVC → Secret → ConfigMap
- All metadata fields (labels, annotations) are optional
- Secret data is not base64 encoded in KCL output (Kubernetes handles encoding)
- ConfigMap supports both text and binary data
- Empty enabled resources are completely omitted from output

## Next Steps

- Add more resource types: ServiceAccount, Role, RoleBinding, etc.
- Add validation schemas for data fields
- Add helper functions for common patterns
- Add support for resource quotas and limits
