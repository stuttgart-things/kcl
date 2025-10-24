# Flux Kustomization KCL Module

Type-safe KCL schemas and helper functions for Flux Kustomization resources, generated from the official Flux CRD definitions.

## Features

- ✅ **Type-Safe CRD Schemas**: Auto-generated from Flux v2.7.2 Kustomization CRD
- ✅ **Simplified Wrappers**: Developer-friendly schemas with sensible defaults
- ✅ **Helper Functions**: Quick creation of common Kustomization patterns
- ✅ **Crossplane Integration**: Built-in support for Crossplane compositions
- ✅ **Complete API Coverage**: Access to full Flux Kustomization v1 and v1beta2 APIs
- ✅ **Health Checks**: Resource health assessment configuration
- ✅ **PostBuild Substitution**: Variable substitution support
- ✅ **Dependency Management**: Define Kustomization dependencies

## Installation

```bash
# Add module to your KCL project
kcl mod add oci://ghcr.io/stuttgart-things/flux-kustomization

# Or add to kcl.mod manually
[dependencies]
flux-kustomization = { oci = "oci://ghcr.io/stuttgart-things/flux-kustomization", tag = "0.1.0" }
```

## Quick Start

### Simple GitRepository Kustomization

```kcl
import flux_kustomization as flux

# Create a basic Kustomization
app = flux.gitKustomization(
    "my-application",      # Name
    "my-git-repo",         # GitRepository name
    "./deploy/production"  # Path in repository
)

items = app
```

### OCI Repository Kustomization

```kcl
import flux_kustomization as flux

app = flux.ociKustomization(
    "my-oci-app",
    "my-oci-repo",
    "./manifests"
)

items = app
```

### Advanced Configuration

```kcl
import flux_kustomization as flux

app = flux.generateKustomization(flux.SimpleKustomization {
    name = "production-app"
    namespace = "flux-system"
    path = "./apps/production"
    sourceRef = flux.SourceRef {
        kind = "GitRepository"
        name = "platform-repo"
    }
    interval = "10m"
    prune = True
    targetNamespace = "production"
    wait = True
    timeout = "10m"
    dependsOn = [
        flux.DependencyRef {
            name = "infrastructure"
        }
    ]
    healthChecks = [
        flux.HealthCheck {
            apiVersion = "apps/v1"
            kind = "Deployment"
            namespace = "production"
        }
    ]
    postBuild = flux.PostBuild {
        substitute = {
            ENVIRONMENT = "production"
            REGION = "eu-west-1"
        }
    }
})

items = app
```

## API Reference

### Simplified Schemas

#### SimpleKustomization

Main configuration schema with sensible defaults:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `str` | *required* | Kustomization name |
| `namespace` | `str` | `"flux-system"` | Namespace for the resource |
| `path` | `str` | `"./"` | Path to kustomization.yaml or YAMLs |
| `sourceRef` | `SourceRef` | *required* | Reference to source |
| `interval` | `str` | `"5m"` | Reconciliation interval |
| `prune` | `bool` | `True` | Enable garbage collection |
| `targetNamespace` | `str` | `None` | Target namespace for resources |
| `dependsOn` | `[DependencyRef]` | `[]` | Dependencies |
| `healthChecks` | `[HealthCheck]` | `[]` | Health check configuration |
| `postBuild` | `PostBuild` | `None` | Variable substitution |
| `wait` | `bool` | `False` | Wait for resources to be ready |
| `force` | `bool` | `False` | Force recreate on immutable changes |
| `timeout` | `str` | `"5m"` | Timeout for operations |
| `suspend` | `bool` | `False` | Suspend reconciliation |

#### SourceRef

Reference to a Flux Source resource:

```kcl
schema SourceRef:
    kind: "GitRepository" | "OCIRepository" | "Bucket"
    name: str
    namespace?: str  # Optional, defaults to same as Kustomization
```

#### DependencyRef

Reference to another Kustomization:

```kcl
schema DependencyRef:
    name: str
    namespace?: str
```

#### HealthCheck

Resource health assessment:

```kcl
schema HealthCheck:
    apiVersion: str
    kind: str
    name?: str
    namespace?: str
```

#### PostBuild

Variable substitution configuration:

```kcl
schema PostBuild:
    substitute?: {str: str}
    substituteFrom?: [SubstituteReference]

schema SubstituteReference:
    kind: "ConfigMap" | "Secret"
    name: str
    optional?: bool = False
```

### Helper Functions

#### generateKustomization

Generate a Flux Kustomization from simplified configuration:

```kcl
generateKustomization = lambda config: SimpleKustomization -> [flux.Kustomization]
```

#### gitKustomization

Quick helper for GitRepository-based Kustomizations:

```kcl
gitKustomization = lambda name: str, gitRepoName: str, path: str = "./" -> [flux.Kustomization]
```

#### ociKustomization

Quick helper for OCIRepository-based Kustomizations:

```kcl
ociKustomization = lambda name: str, ociRepoName: str, path: str = "./" -> [flux.Kustomization]
```

#### generateCrossplaneKustomization

Generate Kustomization from Crossplane XR spec:

```kcl
generateCrossplaneKustomization = lambda -> [flux.Kustomization]
```

**Expected XR Spec Fields:**
- `name`: Kustomization name
- `namespace`: Namespace (default: flux-system)
- `path`: Path in repository (default: ./)
- `sourceKind`: GitRepository, OCIRepository, or Bucket
- `sourceName`: Name of the source
- `sourceNamespace`: Source namespace (optional)
- `interval`: Reconciliation interval (default: 5m)
- `prune`: Enable pruning (default: true)
- `targetNamespace`: Target namespace for resources
- `wait`: Wait for resources (default: false)
- `force`: Force recreate (default: false)
- `suspend`: Suspend reconciliation (default: false)

## Crossplane Integration

### Example XR Definition

```yaml
apiVersion: example.io/v1alpha1
kind: FluxKustomization
metadata:
  name: my-app-kustomization
spec:
  name: my-application
  namespace: flux-system
  sourceKind: GitRepository
  sourceName: platform-repo
  path: ./apps/production
  targetNamespace: production
  interval: 10m
  prune: true
  wait: true
```

### KCL Composition Function

```kcl
import flux_kustomization as flux

# The module automatically reads from Crossplane XR spec
items = flux.generateCrossplaneKustomization()
```

## Examples

### Multi-Environment with Dependencies

```kcl
import flux_kustomization as flux

# Infrastructure layer
infra = flux.gitKustomization(
    "infrastructure",
    "platform-repo",
    "./infrastructure"
)

# Applications depending on infrastructure
apps = flux.generateKustomization(flux.SimpleKustomization {
    name = "applications"
    sourceRef = flux.SourceRef {
        kind = "GitRepository"
        name = "platform-repo"
    }
    path = "./applications"
    dependsOn = [
        flux.DependencyRef {
            name = "infrastructure"
        }
    ]
    prune = True
    wait = True
})

items = infra + apps
```

### With PostBuild Substitutions

```kcl
import flux_kustomization as flux

app = flux.generateKustomization(flux.SimpleKustomization {
    name = "app-with-vars"
    sourceRef = flux.SourceRef {
        kind = "GitRepository"
        name = "my-repo"
    }
    path = "./deploy"
    postBuild = flux.PostBuild {
        substitute = {
            ENVIRONMENT = "production"
            REGION = "eu-west-1"
            REPLICAS = "3"
        }
        substituteFrom = [
            flux.SubstituteReference {
                kind = "ConfigMap"
                name = "cluster-vars"
            },
            flux.SubstituteReference {
                kind = "Secret"
                name = "app-secrets"
                optional = True
            }
        ]
    }
})

items = app
```

## Generated CRD Models

This module includes auto-generated KCL schemas from the official Flux CRDs:

- **v1/kustomize_toolkit_fluxcd_io_v1_kustomization.k** (783 lines)
  - Complete Flux Kustomization v1 API
  - All spec fields with full type safety
  - Status tracking

- **v1beta2/kustomize_toolkit_fluxcd_io_v1beta2_kustomization.k** (755 lines)
  - Legacy v1beta2 API for compatibility

- **k8s/apimachinery/pkg/apis/meta/v1/**
  - Standard Kubernetes metadata types
  - ObjectMeta, OwnerReference, ManagedFieldsEntry

### Direct CRD Usage

You can also use the generated CRD schemas directly for full control:

```kcl
import v1.kustomize_toolkit_fluxcd_io_v1_kustomization as flux

myKustomization = flux.Kustomization {
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind = "Kustomization"
    metadata = {
        name = "my-app"
        namespace = "flux-system"
    }
    spec = {
        interval = "5m"
        path = "./"
        prune = True
        sourceRef = {
            kind = "GitRepository"
            name = "my-repo"
        }
    }
}

items = [myKustomization]
```

## Testing

```bash
# Test simplified schemas
kcl run examples/simple-kustomization.k

# Test Crossplane integration
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "test-app",
      "sourceKind": "GitRepository",
      "sourceName": "test-repo",
      "path": "./test"
    }
  }
}'

# Validate output
kcl run main.k | kubectl apply --dry-run=client -f -
```

## CRD Source

- **Upstream**: [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator)
- **CRD URL**: https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/kustomize-controller.yaml
- **Flux Version**: v2.7.2
- **Conversion Date**: 2025-10-23
- **Conversion Tool**: `stuttgart-things/dagger` KCL module

## Re-generating Models

To update the CRD schemas when Flux releases a new version:

```bash
# Update CRD_VERSION in the command below
FLUX_VERSION="v2.8.0"
CRD_URL="https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/main/config/data/flux/${FLUX_VERSION}/kustomize-controller.yaml"

# Convert using Dagger module
dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
  --crd-source "${CRD_URL}" \
  --progress plain \
  export --path=./updated-models

# Replace existing models
rm -rf v1 v1beta2 k8s
cp -r updated-models/* .
```

## Development

Built following Stuttgart-Things KCL module standards:
- ✅ Crossplane-compliant variable access patterns
- ✅ Explicit boolean handling (False vs undefined)
- ✅ krm.kcl.dev/composition-resource-name annotations
- ✅ Comprehensive documentation and examples
- ✅ Automated CRD conversion using Dagger

## Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Flux Kustomization API](https://fluxcd.io/flux/components/kustomize/kustomization/)
- [KCL Documentation](https://kcl-lang.io/)
- [Stuttgart-Things Standards](../.container-use/decisions.md)
- [Dagger KCL Module](https://github.com/stuttgart-things/dagger/tree/main/kcl)

## License

Apache 2.0 - See LICENSE file

## Contributing

Contributions welcome! Please follow:
1. Stuttgart-Things development standards
2. Use Dagger module for CRD conversions
3. Add tests for new functionality
4. Update documentation and examples
