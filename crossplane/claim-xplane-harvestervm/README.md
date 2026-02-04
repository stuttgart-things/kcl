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
| **Simple** | `harvestervm-simple.yaml` | Name, T-shirt size | Quick provisioning, self-service users |
| **Detailed** | `harvestervm-detailed.yaml` | Name, size, namespace, OS, domain, network, provider, run strategy, KCL template | Platform engineers, team leads |
| **Expert** | `harvestervm-expert.yaml` | All parameters (CPU, memory, storage, PVC, cloudInit, strategies) | Infrastructure admins, full control |

### Simple

Only two questions: **VM name** and **T-shirt size**. Everything else uses sensible defaults with `hidden: true`.

### Detailed

Adds environment-level controls: namespace, provider config, OS, domain, network, and run strategy. Resource sizing still uses T-shirt sizes to keep it straightforward.

### Expert

Full control over all parameters. No T-shirt size abstraction — user sets CPU cores, memory, storage, and all infrastructure details directly.

## T-Shirt Sizes (Simple & Detailed)

| Size | CPU | Memory | Storage |
|------|-----|--------|---------|
| S | 2 | 2Gi | 20Gi |
| M | 4 | 4Gi | 40Gi |
| L | 8 | 8Gi | 80Gi |
| XL | 16 | 16Gi | 160Gi |
| XXL | 32 | 32Gi | 320Gi |

## KCL Templates

The `templateName` parameter (visible in Detailed/Expert, defaults to `demo` in Simple) selects the KCL resource template:

| Template | Description |
|----------|-------------|
| `demo` | Basic 4-core/8Gi VM for testing |
| `production` | High-spec VM with hardened production settings |
| `minimal` | Bare minimum required fields only |

## Usage

### Simple - Quick VM

```bash
kcl run main.k -D name=my-vm -D size=L
```

### Detailed - With environment config

```bash
kcl run main.k -D templateName=production -D name=prod-vm -D size=XL -D namespace=prod -D providerConfigRef=prod
```

### Expert - Full control

```bash
kcl run main.k \
  -D templateName=production \
  -D name=prod-db-01 \
  -D cores=16 \
  -D memory=32Gi \
  -D storage=500Gi \
  -D storageClassName=fast-storage \
  -D runStrategy=Always
```

### Using OCI Registry

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-harvestervm --tag 0.1.0 -D name=my-vm -D size=M
```

## Requirements

- KCL v0.11.2+
- Crossplane with HarvesterVM XRD installed
- Kubernetes provider configured
