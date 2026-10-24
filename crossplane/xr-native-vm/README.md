# XR-NATIVE-VM

KCL module for the native VM XRs on machinery (`resources.stuttgart-things.com/v1alpha1`):

| Lab (`templateName`) | Kind | EnvironmentConfig |
|---|---|---|
| `labda-vsphere` | `NativeVsphereVM` | `vspherevm-labda` |
| `labul-proxmox` (default) | `NativeProxmoxVM` | `proxmoxvm-labul` |

It renders the same object as the Backstage template `create-vm` (baseos use
case): the same t-shirt sizes, the `management-cluster` and `prune: disabled`
annotations, and the `sthings_build_*` markers (with
`sthings_build_source=claim-machinery`). The output belongs in
`clusters/labda/vsphere/machinery-xrs` of stuttgart-things/stuttgart-things.

Replaces the `claim-xplane-vspherevm` (`VsphereVM`, OpenTofu) and
`xr-virtualmachine` (`XVirtualMachine` → `VMProvision`) templates: machinery
runs neither chain any more.

## Sizes

| size | cpu | ram (MB) | disk (GB) |
|---|---|---|---|
| small | 2 | 4096 | 40 |
| medium | 4 | 8192 | 64 |
| large | 8 | 16384 | 100 |
| xlarge | 16 | 24576 | 200 |

`cpu`, `memory` and `disk` override the size individually.

## Parameters

| name | default | |
|---|---|---|
| `templateName` | `labul-proxmox` | lab, see above |
| `name` | `demo-vm` | VM and hostname; the XR is `<name>-vm` |
| `size` | `medium` | small / medium / large / xlarge |
| `ansible` | `true` | emit the VM's AnsibleRun |
| `playbooks` | `sthings.baseos.setup` | comma-separated |
| `extraEnvSecretName` | – | Secret in `tekton-ci` exposed as env to the pipeline |
| `environmentConfig` | `labda` / `labul` | override |
| `claimNamespace` | `default` | |
| `managementCluster` | `machinery` | annotation and build marker |

## Run

```bash
kcl run oci://ghcr.io/stuttgart-things/xr-native-vm --tag 0.1.0 \
  -D templateName=labda-vsphere -D name=my-vm -D size=large \
  -D playbooks=sthings.baseos.setup,sthings.baseos.node_exporter
```

## Templates

- `templates/native-vm-labda-vsphere.yaml`
- `templates/native-vm-labul-proxmox.yaml`

## Schemas

`v1alpha1/` and `k8s/` are generated from the XRD's CRDs on machinery with
`kcl import -m crd` (status removed).
