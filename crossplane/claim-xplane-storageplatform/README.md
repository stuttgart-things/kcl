# claim-xplane-storageplatform

KCL module for generating Crossplane StoragePlatform claims to provision storage backends (NFS or OpenEBS) on Kubernetes clusters.

## Usage (OCI Registry)

### NFS Template

Deploy NFS CSI driver with StorageClass:

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-storageplatform --tag 0.1.1 \
  -D templateName=nfs \
  -D name=nfs-storage \
  -D namespace=default \
  -D serverFQDN=nfs.example.com \
  -D sharePath=/exports/k8s \
  -D storageClass=nfs-client \
  -D mountOptions="vers=4.1,rsize=1048576,wsize=1048576"
```

### OpenEBS Template

Deploy OpenEBS with LVM local provisioner:

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-storageplatform --tag 0.1.1 \
  -D templateName=openebs \
  -D name=openebs-local \
  -D namespace=default \
  -D enableLvm=true \
  -D openebsVersion=4.2.0
```

Deploy OpenEBS with Mayastor:

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-storageplatform --tag 0.1.1 \
  -D templateName=openebs \
  -D name=openebs-mayastor \
  -D namespace=default \
  -D enableMayastor=true \
  -D enableVolumeSnapshots=true \
  -D enableCsiNodeInitContainers=true
```

## Local Development

Standalone template files can be used directly during local development:

```bash
# Run NFS standalone template
kcl run templates/nfs.k -D serverFQDN=nfs.example.com -D sharePath=/exports

# Run OpenEBS standalone template
kcl run templates/openebs.k -D enableLvm=true

# Run via main.k with template selector
kcl run main.k -D templateName=nfs -D serverFQDN=nfs.example.com -D sharePath=/exports
kcl run main.k -D templateName=openebs -D enableLvm=true
```

## Parameters

### Common Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `templateName` | string | `nfs` | Template selector: `nfs` or `openebs` |
| `name` | string | `storage-platform` | Resource name |
| `namespace` | string | `default` | Target namespace |
| `targetClusterName` | string | `in-cluster` | ProviderConfig name |
| `targetClusterScope` | string | `Cluster` | Scope: `Cluster` or `Namespaced` |

### NFS Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serverFQDN` | string | - | NFS server DNS/IP (required) |
| `sharePath` | string | - | NFS share path (required) |
| `storageClass` | string | `nfs-client` | StorageClass name |
| `nfsVersion` | string | `v4.11.0` | NFS CSI driver version |
| `nfsNamespace` | string | `kube-system` | CSI driver namespace |
| `reclaimPolicy` | string | `Delete` | `Delete` or `Retain` |
| `volumeBindingMode` | string | `Immediate` | `Immediate` or `WaitForFirstConsumer` |
| `mountOptions` | string | - | Comma-separated mount options |

### OpenEBS Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `openebsVersion` | string | `4.2.0` | OpenEBS version |
| `openebsNamespace` | string | `openebs-system` | OpenEBS namespace |
| `enableLvm` | bool | `false` | Enable LVM provisioner |
| `enableZfs` | bool | `false` | Enable ZFS provisioner |
| `enableMayastor` | bool | `false` | Enable Mayastor |
| `enableVolumeSnapshots` | bool | `false` | Enable volume snapshots |
| `enableCsiNodeInitContainers` | bool | `false` | Enable CSI init containers |

## Templates

### NFS Template (`templates/nfs.k`)
Full-featured NFS CSI driver deployment with:
- Configurable StorageClass
- Mount options support
- Reclaim policy configuration
- Volume binding mode options

### OpenEBS Template (`templates/openebs.k`)
Complete OpenEBS platform with:
- Local engines (LVM, ZFS)
- Replicated engine (Mayastor)
- Volume snapshot support
- CSI node init containers for Mayastor

## Module Structure

```
claim-xplane-storageplatform/
├── kcl.mod                 # Module manifest
├── kcl.mod.lock            # Lock file
├── README.md               # Documentation
├── main.k                  # Entry point with template selector
├── k8s/apimachinery/       # Kubernetes metadata schemas
│   └── pkg/apis/meta/v1/
│       ├── managed_fields_entry.k
│       ├── object_meta.k
│       └── owner_reference.k
├── v1alpha1/               # StoragePlatform schema
│   └── resources_stuttgart_things_com_v1alpha1_storage_platform.k
└── templates/              # Standalone templates & ClaimTemplate examples
    ├── nfs.k               # NFS standalone template (local dev)
    ├── openebs.k           # OpenEBS standalone template (local dev)
    ├── storageplatform-nfs.yaml      # NFS ClaimTemplate
    └── storageplatform-openebs.yaml  # OpenEBS ClaimTemplate
```

## Related Resources

- [Crossplane storage-platform Configuration](https://github.com/stuttgart-things/crossplane/tree/main/configurations/infra/storage-platform)
- [KCL Documentation](https://kcl-lang.io/)
- [OpenEBS Documentation](https://openebs.io/docs)
- [NFS CSI Driver](https://github.com/kubernetes-csi/csi-driver-nfs)
