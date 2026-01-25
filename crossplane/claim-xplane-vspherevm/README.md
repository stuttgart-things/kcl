# CLAIM-XPLANE-VSPHEREVM

KCL schema for creating vSphere VMs via Crossplane and Terraform provider.

## Templates

| Template | Description |
|----------|-------------|
| `demo` | Basic VM for testing (4GB RAM, 64GB disk, 4 CPU, BIOS) |
| `production` | High-spec VM (16GB RAM, 256GB disk, 8 CPU, EFI firmware) |
| `minimal` | Bare minimum required fields only |

## T-Shirt Sizes

Use the `size` parameter to quickly configure VM resources with predefined configurations:

| Size | RAM | Disk | CPU |
|------|-----|------|-----|
| `S` | 2 GB | 32 GB | 2 cores |
| `M` | 4 GB | 64 GB | 4 cores |
| `L` | 8 GB | 128 GB | 8 cores |
| `XL` | 16 GB | 256 GB | 16 cores |
| `XXL` | 32 GB | 512 GB | 32 cores |

> **Note:** When `size` is specified, it overrides individual `ram`, `disk`, and `cpu` parameters.

## Usage

### Demo Template (default)

```bash
kcl run main.k
```

```bash
kcl run main.k -D templateName=demo
```

### Production Template

```bash
kcl run main.k -D templateName=production -D name=prod-server
```

### Minimal Template

```bash
kcl run main.k -D templateName=minimal -D name=simple-vm
```

### Using T-Shirt Sizes

```bash
kcl run main.k -D size=L -D name=large-vm
```

```bash
kcl run main.k -D templateName=production -D size=XL -D name=prod-xl-server
```

### Custom Parameters

```bash
kcl run main.k -D name=my-vm -D ram=8192 -D cpu=8 -D datacenter=MyDC
```

```bash
kcl run main.k \
  -D name=web-server \
  -D ram=16384 \
  -D disk=128 \
  -D cpu=8 \
  -D folderPath=/Datacenter/vm/web \
  -D datacenter=Production-DC \
  -D datastore=fast-ssd \
  -D resourcePool=Web-Pool \
  -D network="VM Network" \
  -D template=ubuntu-24.04-template
```

### Using OCI Registry

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-vspherevm --tag 0.1.0 \
  -D templateName=production \
  -D name=my-prod-vm
```

## Available Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `templateName` | Template to use (demo, production, minimal) | `demo` |
| `size` | T-shirt size (S, M, L, XL, XXL) - overrides ram/disk/cpu | - |
| `name` | VM name | `demo-vm` |
| `namespace` | Kubernetes namespace | `default` |
| `ram` | RAM in MB | `4096` |
| `disk` | Disk size in GB | `64` |
| `cpu` | Number of CPUs | `4` |
| `count` | Number of VMs to create | `1` |
| `firmware` | Firmware type (bios, efi) | `bios` |
| `folderPath` | vSphere folder path | `/Datacenter/vm/test` |
| `datacenter` | vSphere datacenter | `Datacenter` |
| `datastore` | vSphere datastore | `datastore1` |
| `resourcePool` | vSphere resource pool | `Resources` |
| `network` | vSphere network | `VM Network` |
| `template` | VM template name | `ubuntu-22.04-template` |
| `tfvarsSecretName` | Terraform vars secret name | `vsphere-tfvars` |
| `tfvarsSecretNamespace` | Terraform vars secret namespace | `crossplane-system` |
| `tfvarsSecretKey` | Terraform vars secret key | `terraform.tfvars` |
| `connectionSecretName` | Connection secret name | `${name}-connection` |
| `connectionSecretNamespace` | Connection secret namespace | `${namespace}` |
| `providerRefName` | Provider config name | `default` |
| `providerRefKind` | Provider config kind | `ClusterProviderConfig` |
