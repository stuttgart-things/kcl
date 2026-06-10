# XR-VIRTUALMACHINE

KCL module for the `XVirtualMachine` XR (`resources.stuttgart-things.com/v1alpha1`),
the size/provider/environment abstraction from the
[`virtual-machine` Crossplane Configuration](../../../crossplane/crossplane-configurations/machinery/virtual-machine).

Placement, credentials and topology are **not** set on the claim - they come from
the `EnvironmentConfig` selected by `environment` + `provider`. `vsphere`/`proxmox`
render a `VMProvision` (OpenTofu Workspace); `harvester` renders a `HarvesterVM`
(KubeVirt) directly.

## Templates

| Template | Params | Purpose |
|---|---|---|
| `minimal`  | `size`, `provider`, `environment` | Only the XRD-required fields. `os`/`count`/`ansible` defaulted. |
| `detailed` | + `os`, `count`, `ansible`, `providerRef*` | Every spec field, with an optional ProviderConfig override. |

```bash
# minimal - a small vSphere VM in labul (os=ubuntu24, ansible=true by default)
kcl run oci://ghcr.io/stuttgart-things/xr-virtualmachine --tag 0.1.0 \
  -D templateName=minimal -D name=vm-min -D size=small -D provider=vsphere -D environment=labul
```

```bash
# detailed - a medium Harvester VM, ansible off, explicit providerRef override
kcl run oci://ghcr.io/stuttgart-things/xr-virtualmachine --tag 0.1.0 \
  -D templateName=detailed -D name=vm-harv -D size=medium -D provider=harvester \
  -D environment=labul -D os=ubuntu24 -D count=1 -D ansible=false \
  -D providerRefName=default -D providerRefKind=ClusterProviderConfig
```

`count` is kept a string (XRD type) even when numeric, and `ansible` accepts
`true`/`false`/`1`/`0`/`yes`. `providerRef` is only emitted when
`providerRefName` is non-empty.
