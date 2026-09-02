# XPLANE-HARVESTER-VM

## Quick Start with -D params

Run the module with full configuration via `-D params`:

```bash
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
      "storageClassName": "",
      "volumeMode": "Block",
      "accessModes": ["ReadWriteMany"],
      "secretName": "dev2-cloud-init", # pragma: allowlist secret
      "userdata": "I2Nsb3VkLWNvbmZpZwp3cml0ZV9maWxlczoKICAvZXRjL2hvc3RuYW1lOgogICAgY29udGVudDogZGV2Mgo=", # pragma: allowlist secret
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

## Storage class

The PVC's class comes from one of two places in `spec`:

| Set | Resulting `storageClassName` |
|---|---|
| `storageClass` only (default) | `<storageClass>-<imageId>`, e.g. `longhorn-image-generic` |
| `storageClassName` | the value verbatim; `storageClass` is ignored |

Harvester creates one StorageClass per VM image and names it `lh-<uuid>`, not
`<class>-<image>`. `imageId` cannot be bent to match, because the PVC's
`harvesterhci.io/imageId` annotation needs it correct. So on a current cluster,
look the class up and set it directly:

```bash
kubectl get virtualmachineimages -n default \
  -o custom-columns='NAME:.metadata.name,SC:.status.storageClassName'
```

```json
"imageId": "sthings-u26",
"storageClassName": "lh-68e4c918-0059-48bf-acaf-0de0ebe1eb65"
```

Getting this wrong does not fail loudly: the PVC binds to a class that does not
exist and stays `Pending`, the VirtualMachine applies fine, and KubeVirt never
instantiates it — so the `Object` reports healthy while nothing boots.

## VM Only (without PVC and Cloud Config)

Run the module with VM only (no persistent volume or cloud-init secret):

```bash
kcl run oci://ghcr.io/stuttgart-things/xplane-harvester-vm --tag 0.4.0 -D params='{
  "oxr": {
    "spec": {
      "name": "dev2",
      "namespace": "vms",
      "vmName": "dev2-vm",
      "hostname": "dev2",
      "description": "Development VM",
      "osLabel": "ubuntu",
      "runStrategy": "RerunOnFailure",
      "cpuCores": 4,
      "cpuSockets": 1,
      "cpuThreads": 1,
      "memory": "8Gi",
      "diskName": "disk-0",
      "machineType": "q35",
      "networkNamespace": "default",
      "networkName": "default",
      "evictionStrategy": "LiveMigrateIfPossible",
      "terminationGracePeriod": 120
    }
  }
}' --format yaml | grep -A 1000 "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```
