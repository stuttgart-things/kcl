# XR-NAMESPACE

KCL module for the `ManagedNamespace` XR (`resources.stuttgart-things.com/v1alpha1`),
which declaratively creates/adopts a `Namespace` on a target cluster via the
[`namespace` Crossplane Configuration](../../../crossplane/crossplane-configurations/k8s/namespace).

## Templates

| Template | Description |
|---|---|
| `minimal`   | Simplest option - just a namespace `name` and a target cluster (`providerConfig`). |
| `annotated` | `name` + target cluster + a generic, user-defined `annotations` map applied to the Namespace. |

```bash
# minimal - just a name and a target cluster
kcl run oci://ghcr.io/stuttgart-things/xr-namespace --tag 0.1.1 \
  -D templateName=minimal -D name=team-alpha -D providerConfig=in-cluster
```

```bash
# annotated - generic annotations as a comma-separated key=value string.
# Reproduces the Harvester `vms` case (assign the namespace to the Rancher
# "Default" project so the UI lists the VMs running in it):
kcl run oci://ghcr.io/stuttgart-things/xr-namespace --tag 0.1.1 \
  -D templateName=annotated -D name=vms -D providerConfig=harvester \
  -D annotations='field.cattle.io/projectId=c-cxgxd:p-sfgv4'
```

The `annotations` parameter is a comma-separated `key=value` string, e.g.
`field.cattle.io/projectId=c-cxgxd:p-sfgv4,owner=team-x`. It is a string (not an
object) on purpose: the claim-machinery API renders OCI modules via `kcl -D
key=value` and cannot round-trip object params, so a string is parsed in
`main.k` instead. `providerConfig` is free text (no fixed enum) so profiles can
target a ProviderConfig that isn't in the common list.
