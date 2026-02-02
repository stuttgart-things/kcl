# CLAIM-XPLANE-HARVESTERVM

KCL schema for creating Harvester VMs via Crossplane.

## Overview

This module provides a type-safe KCL interface for creating HarvesterVM claims that provision:
- Persistent Volume Claims (PVC) for VM storage
- Cloud-Init secrets for VM bootstrap configuration
- KubeVirt/Harvester VirtualMachine resources

## Templates

| Template | Description |
|----------|-------------|
| `demo` | Basic 4-core/8Gi VM for testing |
| `production` | High-spec 8-core/16Gi/100Gi VM with production settings |
| `minimal` | Bare minimum required fields only |

## T-Shirt Sizes

| Size | Memory | Storage | CPU |
|------|--------|---------|-----|
| S | 2Gi | 20Gi | 2 |
| M | 4Gi | 40Gi | 4 |
| L | 8Gi | 80Gi | 8 |
| XL | 16Gi | 160Gi | 16 |
| XXL | 32Gi | 320Gi | 32 |

## Usage

### Demo Template (default)

```bash
kcl run main.k
```

### Custom Parameters

```bash
kcl run main.k -D name=my-vm -D cores=8 -D memory=16Gi
```

### Using T-Shirt Sizes

```bash
kcl run main.k -D name=my-vm -D size=L
```

### Production Template

```bash
kcl run main.k -D templateName=production -D name=prod-server
```

### Using OCI Registry

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-harvestervm --tag 0.1.0 -D name=my-vm
```

## Available Parameters

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | VM and claim name | `demo-harvester-vm` |
| `namespace` | Kubernetes namespace | `default` |
| `templateName` | Template type | `demo` |
| `size` | T-shirt size (overrides resources) | - |
| `providerConfigRef` | Provider config name | `dev` |

### Volume Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pvcName` | PVC name | `<name>-root` |
| `storageClassName` | Storage class | `harvester-longhorn` |
| `storage` | Storage size | `20Gi` |
| `volumeMode` | Volume mode | `Filesystem` |

### CloudInit Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hostname` | VM hostname | first part of name |
| `domain` | Domain name | `stuttgart-things.local` |
| `timezone` | Timezone | `Europe/Berlin` |

### VM Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cores` | CPU cores | `4` |
| `memory` | Memory | `8Gi` |
| `cpuResource` | CPU resource limit | `4` |
| `os` | Operating system | `ubuntu` |
| `runStrategy` | Run strategy | `RerunOnFailure` |
| `evictionStrategy` | Eviction strategy | `LiveMigrateIfPossible` |
| `networkName` | Network (namespace/name) | `default/default` |

## Examples

### Basic VM

```bash
kcl run main.k -D name=test-vm
```

### Production VM with custom specs

```bash
kcl run main.k \
  -D templateName=production \
  -D name=prod-db-01 \
  -D cores=16 \
  -D memory=32Gi \
  -D storage=500Gi \
  -D storageClassName=fast-storage
```

### Minimal VM

```bash
kcl run main.k -D templateName=minimal -D name=minimal-vm
```

## Requirements

- KCL v0.11.2+
- Crossplane with HarvesterVM XRD installed
- Kubernetes provider configured
