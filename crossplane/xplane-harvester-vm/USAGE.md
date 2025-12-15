# xplane-harvester-vm Usage

## Quick Start with -D params

Run the module with full configuration via `-D params`:

```bash
cd /home/sthings/projects/kcl/crossplane/xplane-harvester-vm && \
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "dev2",
      "namespace": "vms",
      "vmName": "dev2-vm",
      "hostname": "dev2",
      "description": "Development VM",
      "pvcName": "dev2-disk-0",
      "imageNamespace": "harvester-public",
      "imageId": "image-ubuntu-22.04",
      "storage": "30Gi",
      "storageClass": "longhorn",
      "volumeMode": "Block",
      "accessModes": ["ReadWriteMany"],
      "secretName": "dev2-cloud-init",  // pragma: allowlist secret
      "userdata": "I2Nsb3VkLWNvbmZpZwp3cml0ZV9maWxlczoKICAvZXRjL2hvc3RuYW1lOgogICAgY29udGVudDogZGV2Mgo=",  // pragma: allowlist secret
      "networkdata": "",
      "osLabel": "ubuntu",
      "runStrategy": "RerunOnFailure",
      "cpuCores": 4,
      "cpuSockets": 1,
      "cpuThreads": 1,
      "memory": "8Gi",
      "diskName": "disk-0",
      "machineType": "q35",
      "networkNamespace": "vms",
      "networkName": "vms",
      "evictionStrategy": "LiveMigrateIfPossible",
      "terminationGracePeriod": 120,
      "enablePvc": true,
      "enableSecret": true,
      "enableVm": true
    }
  }
}' --format yaml | grep -A 1000 "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```

## Explanation

### Parameters Breakdown

**Basic VM Config:**
- `name`: VMs identifier (used in labels, annotations)
- `namespace`: Target namespace
- `vmName`: VirtualMachine resource name
- `hostname`: System hostname
- `description`: VM description

**PVC Config:**
- `pvcName`: PersistentVolumeClaim name
- `imageNamespace`: Harvester image namespace
- `imageId`: Harvester image identifier
- `storage`: Disk size (e.g., "30Gi")
- `storageClass`: Storage class name (default: "longhorn")
- `volumeMode`: "Block" or "Filesystem"
- `accessModes`: Access modes array

**Secret Config:**
- `secretName`: Cloud-init secret name
- `userdata`: Base64-encoded cloud-config
- `networkdata`: Base64-encoded network-config

**VM Resources:**
- `osLabel`: OS label for VM
- `runStrategy`: "RerunOnFailure" or "Halted"
- `cpuCores`: CPU cores
- `cpuSockets`: CPU sockets
- `cpuThreads`: CPU threads
- `memory`: Memory size (e.g., "8Gi")
- `machineType`: "q35" (default)
- `networkNamespace`: Network namespace
- `networkName`: Network name for Multus
- `evictionStrategy`: "LiveMigrateIfPossible"
- `terminationGracePeriod`: Termination grace period in seconds

**Control Flags:**
- `enablePvc`: Enable PersistentVolumeClaim
- `enableSecret`: Enable cloud-init Secret
- `enableVm`: Enable VirtualMachine

## Output Formats

### All Resources Enabled (3 Crossplane Objects)
When all 3 resources are enabled, output is an array of Crossplane Objects:
```yaml
- apiVersion: kubernetes.crossplane.io/v1alpha2
  kind: Object
  metadata:
    name: dev2-disk-0
  # ... PVC manifest
---
- apiVersion: kubernetes.crossplane.io/v1alpha2
  kind: Object
  metadata:
    name: dev2-cloud-init
  # ... Secret manifest
---
- apiVersion: kubernetes.crossplane.io/v1alpha2
  kind: Object
  metadata:
    name: dev2-vm
  # ... VirtualMachine manifest
```

### Single Resource (Direct Object)
When only one resource is enabled, output is a single Crossplane Object (no array):
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: dev2-disk-0
# ... PVC manifest
```

### Apply to Cluster

```bash
# Apply with kubectl
kcl run main.k -D params='...' --format yaml | kubectl apply -f -

# Or with the grep/sed piping:
kcl run main.k -D params='...' --format yaml | \
  grep -A 1000 "^items:" | \
  sed 's/^- /---\n/' | \
  sed '1d' | \
  sed 's/^  //' | \
  kubectl apply -f -
```

## Alternative: Use Config File

For easier management, use a config file instead:

```bash
kcl run main.k example-config.kcl --format yaml | kubectl apply -f -
```

## Encoding Base64 Cloud-Config

To generate userdata parameter:

```bash
# Create cloud-config file
cat > cloud-init.yaml << 'EOF'
#cloud-config
write_files:
  - path: /etc/hostname
    content: dev2
EOF

# Encode to Base64
base64 -w0 cloud-init.yaml
# Output: I2Nsb3VkLWNvbmZpZwp3cml0ZV9maWxlczoKICAvZXRjL2hvc3RuYW1lOgogICAgY29udGVudDogZGV2Mgo=

# Use this as userdata parameter
```

Or use the helper script:

```bash
./../../kubernetes/resources/render-secret.sh cloud-init.yaml
```

## Examples

### PVC Only
```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "storage1",
      "namespace": "storage",
      "pvcName": "data-disk-1",
      "storage": "100Gi",
      "enablePvc": true,
      "enableSecret": false,
      "enableVm": false
    }
  }
}' --format yaml
```

### VM Only
```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vm1",
      "vmName": "vm1-machine",
      "cpuCores": 2,
      "memory": "4Gi",
      "enablePvc": false,
      "enableSecret": false,
      "enableVm": true
    }
  }
}' --format yaml
```

### Full Stack (Recommended)
Use `example-config.kcl` or the full `-D params` command above.

## Crossplane Integration

In a Crossplane Composition, the XR spec is passed as `option("params")`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xharvestervms.example.com
spec:
  group: example.com
  names:
    kind: XHarvesterVM
  claimNames:
    kind: HarvesterVM
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
              name:
                type: string
              namespace:
                type: string
              vmName:
                type: string
              # ... all other properties
```

The KCL function will receive this spec via `option("params").oxr.spec`.
