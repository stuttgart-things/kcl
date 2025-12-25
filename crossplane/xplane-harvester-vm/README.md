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
      "volumeMode": "Block",
      "accessModes": ["ReadWriteMany"],
      "secretName": "dev2-cloud-init",
      "userdata": "I2Nsb3VkLWNvbmZpZwp3cml0ZV9maWxlczoKICAvZXRjL2hvc3RuYW1lOgogICAgY29udGVudDogZGV2Mgo=",
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

## VM Only (without PVC and Cloud Config)

Run the module with VM only (no persistent volume or cloud-init secret):

```bash
kcl run main.k -D params='{
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
      "networkNamespace": "vms",
      "networkName": "vms",
      "evictionStrategy": "LiveMigrateIfPossible",
      "terminationGracePeriod": 120
    }
  }
}' --format yaml | grep -A 1000 "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```
