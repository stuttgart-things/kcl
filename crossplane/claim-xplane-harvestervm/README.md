# CLAIM-XPLANE-HARVESTERVM

KCL schema for creating Harvester VMs via Crossplane.

## Overview

This module provides a type-safe KCL interface for creating HarvesterVM claims that provision:
- Persistent Volume Claims (PVC) for VM storage
- Cloud-Init secrets for VM bootstrap configuration
- KubeVirt/Harvester VirtualMachine resources

## ClaimTemplates

Three ClaimTemplate tiers are available to reduce cognitive load for different user levels:

| Template | File | User gets prompted for | Use case |
|----------|------|----------------------|----------|
| **Developer** | `harvestervm-developer.yaml` | Name, count, T-shirt size, packages, image | Quick provisioning, self-service developers |
| **Detailed** | `harvestervm-detailed.yaml` | Name, size, namespace, OS, domain, network, provider, run strategy, KCL template | Platform engineers, team leads |
| **Expert** | `harvestervm-expert.yaml` | All parameters (CPU, memory, storage, PVC, cloudInit, strategies) | Infrastructure admins, full control |

### Developer

Five simple questions: **VM name**, **count**, **T-shirt size**, **packages**, and **image**. Everything else uses sensible defaults with `hidden: true`. Uses the `minimal` KCL template by default.

### Detailed

Adds environment-level controls: namespace, provider config, OS, domain, network, and run strategy. Resource sizing still uses T-shirt sizes to keep it straightforward.

### Expert

Full control over all parameters. No T-shirt size abstraction — user sets CPU cores, memory, storage, and all infrastructure details directly.

## T-Shirt Sizes (Developer & Detailed)

| Size | CPU | Memory | Storage |
|------|-----|--------|---------|
| S | 2 | 2Gi | 20Gi |
| M | 4 | 4Gi | 40Gi |
| L | 8 | 8Gi | 80Gi |
| XL | 16 | 16Gi | 160Gi |
| XXL | 32 | 32Gi | 320Gi |

## VM Images

The `image` parameter provides friendly aliases for Harvester VM images:

| Alias | Description | Image ID |
|-------|-------------|----------|
| `ubuntu25` | Ubuntu 25.04 (Plucky Puffin) | `image-t9w92` |
| `ubuntu22` | Ubuntu 22.04 LTS | `image-lg5qf` |
| `rocky9` | Rocky Linux 9 | `image-k7m2x` |
| `rocky8` | Rocky Linux 8 | `image-r4n9p` |
| `debian12` | Debian 12 | `image-d3b7k` |
| `opensuse15` | openSUSE Leap 15 | `image-s5v2m` |
| `opensuse-micro` | openSUSE MicroOS | `image-m5bh6` |

**Developer template** offers: `ubuntu25` (default), `opensuse-micro`

### Image Configuration

When an image alias is selected:
- **StorageClass** is auto-generated as `longhorn-{imageId}` (e.g., `longhorn-image-t9w92`)
- **Volume annotation** `harvesterhci.io/imageId` is set to `{namespace}/{imageId}`
- **VolumeMode** defaults to `Block`
- **AccessModes** defaults to `ReadWriteMany`

For advanced use, you can override with direct `imageId` parameter.

## KCL Templates

The `templateName` parameter selects the KCL resource template:

| Template | Description |
|----------|-------------|
| `minimal` | Bare minimum required fields only (default for Developer) |
| `demo` | Basic 4-core/8Gi VM for testing |
| `production` | High-spec VM with hardened production settings |

## Usage

### Developer - Quick VM with image selection

```bash
# Ubuntu 25.04 VM (default)
kcl run . -D templateName=minimal -D name=my-vm -D size=L -D image=ubuntu25

# openSUSE MicroOS VM
kcl run . -D templateName=minimal -D name=my-suse-vm -D size=M -D image=opensuse-micro
```

With custom packages:

```bash
kcl run . -D templateName=minimal -D name=myvm -D size=M -D image=ubuntu25 \
  -D 'packages=["curl","vim","htop"]'
```

### Detailed - With environment config

```bash
kcl run . -D templateName=production -D name=prod-vm -D size=XL \
  -D namespace=prod -D providerConfigRef=prod -D image=ubuntu25
```

### Expert - Full control with direct imageId

```bash
kcl run . \
  -D templateName=production \
  -D name=prod-db-01 \
  -D cores=16 \
  -D memory=32Gi \
  -D storage=500Gi \
  -D imageId=image-custom123 \
  -D storageClassName=longhorn-image-custom123 \
  -D runStrategy=Always
```

### Using OCI Registry

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-harvestervm --tag 0.1.2 \
  -D name=my-vm -D size=M -D image=ubuntu25
```

## Example Output

With `image=ubuntu25` and `size=L`:

```yaml
apiVersion: resources.stuttgart-things.com/v1alpha1
kind: HarvesterVM
metadata:
  name: my-vm
  namespace: default
spec:
  providerConfigRef: dev
  volume:
    pvcName: my-vm-root
    namespace: default
    storageClassName: longhorn-image-t9w92
    storage: '80Gi'
    accessModes:
      - ReadWriteMany
    volumeMode: Block
    annotations:
      harvesterhci.io/imageId: default/image-t9w92
  cloudInit:
    vmName: my-vm
    namespace: default
    hostname: my
    domain: stuttgart-things.local
    timezone: Europe/Berlin
    packages:
      - curl
    packageUpdate: true
    packageUpgrade: false
    sshPasswordAuth: false
    disableRoot: true
  vm:
    cpu:
      cores: 8
    resources:
      memory: '8Gi'
      cpu: '8'
    disks:
      - name: rootdisk
      - name: cloudinitdisk
    networks:
      - name: default
        networkName: default/default
```

## Requirements

- KCL v0.11.2+
- Crossplane with HarvesterVM XRD installed
- Kubernetes provider configured
- Harvester cluster with VM images uploaded
