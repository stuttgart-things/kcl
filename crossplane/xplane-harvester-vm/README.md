# Crossplane Harvester VM Module

KCL module for rendering Harvester VMs as Crossplane `kubernetes.crossplane.io/v1alpha2/Object` resources.

This module wraps Harvester VM infrastructure (PersistentVolumeClaim, Secret, VirtualMachine) into Crossplane-managed objects that can be provisioned through XRDs.

## Features

- **Crossplane Compatible**: Renders resources as `kubernetes.crossplane.io/v1alpha2/Object`
- **XR Spec Integration**: Uses `option("params")?.oxr?.spec` pattern for configuration
- **K8s Library**: Uses official KCL Kubernetes library (v1.32.4)
- **Resource Control**: Explicit enable flags for PVC, Secret, and VirtualMachine
- **Cloud-Init Support**: Handles cloud-config secrets for VM initialization
- **Network Configuration**: Multus/CNI network integration

## Pattern: Optional Chaining with Null Safety

The module uses KCL's optional chaining (`?.`) with conditional fallback for safe field access:

```kcl
_params = option("params")
name = _params?.oxr?.spec.name or "" if _params else ""
namespace = _params?.oxr?.spec.namespace or "default" if _params else "default"
# All fields follow this pattern
```

This ensures safety when `option("params")` is `None` and works in three modes:
1. **Crossplane Mode**: XR spec passed via `option("params")` automatically
2. **Config File Mode**: Create `harvester-vm-config.kcl` with `_params = { oxr = { spec = {...} } }`
3. **Standalone Mode**: Uses all defaults if no parameters provided

## Quick Start

### Using Config File (Recommended)

See `example-config.kcl` for a complete working example. Then run:

```bash
cd /home/sthings/projects/kcl/crossplane/xplane-harvester-vm
kcl run main.k example-config.kcl --format yaml | kubectl apply -f -
```

### Using CLI (-D params)

For inline configuration, use `-D params` with JSON structure (see [USAGE.md](./USAGE.md) for full examples):

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "dev2",
      "namespace": "vms",
      "vmName": "dev2-vm",
      "pvcName": "dev2-disk-0",
      "imageNamespace": "harvester-public",
      "imageId": "image-ubuntu-22.04",
      "storage": "30Gi",
      "cpuCores": 4,
      "memory": "8Gi",
      "enablePvc": true,
      "enableSecret": true,
      "enableVm": true
    }
  }
}' --format yaml | kubectl apply -f -
```

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
      "osLabel": "ubuntu",
      "cpuCores": 4,
      "memory": "8Gi",
      "enablePvc": true,
      "enableSecret": true,
      "enableVm": true
    }
  }
}' --format yaml


### Create Your Own Config File

Create `harvester-vm-config.kcl` with the params structure:

```kcl
# harvester-vm-config.kcl
_params = {
    oxr = {
        spec = {
            name = "dev2"
            namespace = "default"
            vmName = "dev2-vm"
            hostname = "dev2"
            description = "Development VM"

            # PVC Configuration
            pvcName = "dev2-disk-0"
            imageNamespace = "default"
            imageId = "image-ubuntu-22.04"
            storage = "20Gi"
            storageClass = "longhorn"
            volumeMode = "Block"
            accessModes = ["ReadWriteMany"]

            # Secret Configuration  # pragma: allowlist secret
            secretName = "dev2-cloud-init"  # pragma: allowlist secret
            userdata = "I2Nsb3VkLWNvbmZpZwpob3N0bmFtZTogZGV2Mg=="  # pragma: allowlist secret
            networkdata = ""

            # VM Configuration
            osLabel = "linux"
            runStrategy = "RerunOnFailure"
            cpuCores = 8
            cpuSockets = 1
            cpuThreads = 1
            memory = "12Gi"
            diskName = "disk-0"
            machineType = "q35"
            networkName = "vms"
            networkNamespace = "default"
            evictionStrategy = "LiveMigrateIfPossible"
            terminationGracePeriod = 120

            # Control Flags - enable resource rendering
            enablePvc = True
            enableSecret = True
            enableVm = True
        }
    }
}
```

Render with:
```bash
kcl run main.k harvester-vm-config.kcl --format yaml
```

Output single Crossplane Object for each enabled resource.

### Output Formats

The module automatically handles output:

- **Single Resource** (1 enabled): Returns direct Crossplane Object dict
  ```bash
  kcl run main.k example-pvc-only.kcl --format yaml  # Single Object
  ```

- **Multiple Resources** (2+ enabled): Returns array of Crossplane Objects
  ```bash
  kcl run main.k example-config.kcl --format yaml   # Array of 3 Objects
  ```

- **No Resources** (none enabled): Returns empty array
  ```bash
  kcl run main.k --format yaml                      # items: []
  ```

All formats are valid Kubernetes YAML for `kubectl apply -f -`.

### Testing with Local Config

Create a minimal test config:

```kcl
_params = {
    oxr = {
        spec = {
            name = "test-vm"
            namespace = "default"
            vmName = "test-vm"
            cpuCores = 4
            memory = "8Gi"
            enablePvc = True
            enableSecret = True
            enableVm = True
        }
    }
}
```

Then render:
```bash
kcl run main.k test-config.kcl --format yaml
```

### Crossplane Integration (Production)

In Crossplane, use this module in a Composition. The KCL function receives the XR spec via `option("params").oxr.spec`.

Example Composition patch:
```yaml
- step: render-harvester-vm
  functionRef:
    name: crossplane-contrib-function-kcl
  input:
    apiVersion: kcl.crossplane.io/v1alpha1
    kind: KCLInput
    spec:
      source: oci://ghcr.io/stuttgart-things/kcl-xplane-harvester-vm:v0.1.0
      # The KCL module automatically receives the XR as option("params")
```

### XRD Reference FormatExpected XR spec fields:

```yaml
spec:
  name: dev2
  namespace: default
  vmName: dev2
  hostname: dev2

  # PVC Configuration
  pvcName: dev2-disk-0
  imageNamespace: default
  imageId: image-t9w92
  storage: 10Gi
  storageClass: longhorn
  volumeMode: Block
  accessModes: [ReadWriteMany]

  # Secret Configuration
  secretName: dev2-cloud-init
  userdata: "I2Nsb3VkLWNvbmZpZw..." # Base64-encoded
  networkdata: ""

  # VM Configuration
  osLabel: linux
  runStrategy: RerunOnFailure
  cpuCores: 8
  memory: 12Gi
  diskName: disk-0
  machineType: q35
  networkName: vms
  networkNamespace: default

  # Control Flags
  enablePvc: true
  enableSecret: true
  enableVm: true
```

### Rendering with Composition

In Crossplane Composition, use the KCL module to generate resources:

```yaml
- name: harvester-vm
  base:
    apiVersion: kubernetes.crossplane.io/v1alpha2
    kind: Object
    # ...
  patches:
    - type: FromCompositeFieldValue
      fromFieldPath: spec.vmConfig
      toFieldPath: metadata.labels
```

## XR Spec Fields Reference

### Basic Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | VM identifier and base name |
| `namespace` | string | "default" | Target namespace |
| `vmName` | string | `name` | VirtualMachine resource name |
| `hostname` | string | `vmName` | VM hostname (cloud-init) |
| `description` | string | "${vmName} vm" | VM description |

### PVC Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `pvcName` | string | "${vmName}-disk-0" | PVC name |
| `imageNamespace` | string | "default" | Harvester image namespace |
| `imageId` | string | "image-generic" | Harvester image ID |
| `storage` | string | "10Gi" | Storage size |
| `storageClass` | string | "longhorn" | Storage class name |
| `volumeMode` | string | "Block" | Filesystem or Block |
| `accessModes` | array | ["ReadWriteMany"] | PVC access modes |

### Secret Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `secretName` | string | "${vmName}-cloud-init" | Secret name |
| `userdata` | string | "" | Base64-encoded cloud-config |
| `networkdata` | string | "" | Base64-encoded network-config |

### VM Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `osLabel` | string | "linux" | OS label |
| `runStrategy` | string | "RerunOnFailure" | VM run strategy |
| `cpuCores` | int | 4 | CPU cores |
| `cpuSockets` | int | 1 | CPU sockets |
| `cpuThreads` | int | 1 | CPU threads |
| `memory` | string | "8Gi" | Memory allocation |
| `diskName` | string | "disk-0" | Disk volume name |
| `machineType` | string | "q35" | QEMU machine type |
| `networkName` | string | "vms" | Network/CNI name |
| `networkNamespace` | string | `namespace` | Network namespace |
| `evictionStrategy` | string | "LiveMigrateIfPossible" | Eviction strategy |
| `terminationGracePeriod` | int | 120 | Termination grace period (seconds) |

### Control Flags

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enablePvc` | bool | true | Render PVC resource |
| `enableSecret` | bool | true | Render Secret resource |
| `enableVm` | bool | true | Render VirtualMachine resource |

## XR Spec Pattern

This module uses the Crossplane XR spec pattern:

```kcl
# Get values from XR spec with fallback defaults
name = option("params")?.oxr?.spec.name or ""
vmName = option("params")?.oxr?.spec.vmName or name
storage = option("params")?.oxr?.spec.storage or "10Gi"

# Boolean flags with explicit type checking
_enablePvcValue = option("params")?.oxr?.spec.enablePvc
enablePvc = True if _enablePvcValue == True or _enablePvcValue == "true" or _enablePvcValue == None else False
```

## Resource Output Structure

Each resource is wrapped as a Crossplane `kubernetes.crossplane.io/v1alpha2/Object`:

```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: dev2-disk-0
  labels:
    app.kubernetes.io/managed-by: crossplane
spec:
  deletionPolicy: Delete
  forProvider:
    manifest:
      # Actual Kubernetes resource (PVC, Secret, VirtualMachine)
      apiVersion: v1
      kind: PersistentVolumeClaim
      # ...
  managementPolicies: ["*"]
```

## Module Output

- **Single resource**: Direct resource object
- **Multiple resources**: Array of resources (when multiple enable flags are true)

## Example XR Definition

```yaml
apiVersion: example.com/v1
kind: HarvesterVM
metadata:
  name: dev2
spec:
  name: dev2
  namespace: prod
  vmName: dev2-vm
  cpuCores: 8
  memory: 16Gi
  imageId: image-ubuntu-22.04
  storage: 50Gi
  enablePvc: true
  enableSecret: true
  enableVm: true
```

## Integration with Crossplane

Use this module in a Composition:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: harvester-vm-composition
spec:
  compositeTypeRef:
    apiVersion: example.com/v1
    kind: HarvesterVM
  resources:
    - name: vm-resources
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
      patches:
        # Map XR spec to Object patch
        - type: FromCompositeFieldValue
          fromFieldPath: spec.vmConfig
          toFieldPath: spec.forProvider.manifest
```

## Testing

```bash
# Render single resource
kcl run main.k -D enablePvc=true --format yaml

# Render all resources
kcl run main.k --format yaml

# With config file
kcl run main.k harvester-vm-config.kcl --format yaml
```

## Version

- **Module Version**: 0.1.0
- **KCL Version**: 0.12.3+
- **Kubernetes Version**: 1.32.4
- **Crossplane Kubernetes Provider**: v1alpha2
