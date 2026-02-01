# KCL Modules

A collection of KCL (Kusion Configuration Language) modules for Kubernetes, Crossplane, and Flux resources.

## Overview

This repository provides type-safe, reusable KCL modules for:

- Crossplane claim templates (vSphere VMs, storage platforms, etc.)
- Kubernetes resources
- Flux CD configurations

## Repository Structure

| Directory | Description |
|-----------|-------------|
| `crossplane/` | Crossplane claim modules (claim-xplane-*) |
| `kubernetes/` | Kubernetes resource modules |
| `flux/` | Flux CD configuration modules |
| `models/` | Shared KCL models and schemas |
| `tests/` | Module tests |

## Quick Start

### Running a Crossplane Claim Module

```bash
# Using local module
cd crossplane/claim-xplane-vspherevm
kcl run main.k -D name=my-vm

# Using OCI registry
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-vspherevm --tag 0.1.0 -D name=my-vm
```

### Publishing to OCI Registry

```bash
cd crossplane/claim-xplane-<module>
kcl mod push oci://ghcr.io/stuttgart-things/claim-xplane-<module>
```

## Available Modules

### Crossplane Claim Modules

| Module | Description |
|--------|-------------|
| `claim-xplane-vspherevm` | vSphere VM provisioning via Terraform provider |
| `claim-xplane-storageplatform` | Storage platform provisioning |

## Related Documentation

- [Creating Claim Modules](creating-claim-modules.md)
