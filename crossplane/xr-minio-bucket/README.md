# XR-MINIO-BUCKET

KCL module for **MinIO bucket orders**: the `MinioBucket` XR
(`storage.stuttgart-things.com/v1alpha1`) of crossplane-configurations
`storage/minio`, as claim-machinery-api renders it for machinery-order-service
and the claims CLI (stuttgart-things/stuttgart-things#4822).

It writes the same XR as the hand-written buckets in
`clusters/labda/vsphere/machinery-xrs/minio-*.yaml`; `tests/` renders it
against them (see [Tests](#tests)).

ClaimTemplate: [`templates/minio-bucket.yaml`](templates/minio-bucket.yaml),
`orderRoles: [backstage-platform]` (platform team only for now).

## Output

One `MinioBucket` (cluster-scoped, so no namespace), named after the bucket:

| | |
|---|---|
| `metadata.labels`, `metadata.annotations` `stuttgart-things.com/order-id` | when `order_id` is set |
| `stuttgart-things.com/management-cluster` | `management_cluster` (default `machinery`) |
| `stuttgart-things.com/source-path` | `source_path`, default `<orders directory>/minio-<name>.yaml` |
| `stuttgart-things.com/requested-by` / `owner` | `requested_by` (`identity: user`) / `owner` (`identity: owner`, default = orderer) |
| `kustomize.toolkit.fluxcd.io/prune: disabled` | always: orders are deleted file first, then the XR |
| `spec.providerConfigRef.name` | `provider_config` |
| `spec.bucketName` | `name` |
| `spec.deletionPolicy` | `deletion_policy`, **always written**, also the default `Orphan` |
| `spec.access` | with `user` (default): one entry `writer`, `scope: bucket`, keys in Secret `default/<name>` |

Orders directories: `machinery` → `clusters/labda/vsphere/machinery-orders-xrs`,
`machinery-labul` → `clusters/labul/proxmox/machinery-labul-orders-xrs`. Another
management cluster needs `source_path` (machinery-order-service always sets it
from the ManagementCluster's `ordersPath`).

## ProviderConfig

| `provider_config` | MinIO | on |
|---|---|---|
| `minio-labda` (default) | LabDA, sthings-platform (`minio.sthings-platform.4sthings.tiab.ssc.sva.de`) | `machinery` |
| `minio` | LabUL, platform-sthings (`artifacts.platform.sthings-vsphere.labul.sva.de`) | `machinery`, `machinery-labul` |

**`minio-labda` exists only on `machinery`.** **`minio` is the LabUL MinIO on
both management clusters** -- also on `machinery` (LabDA), where it is not the
lab's own MinIO: a bucket ordered there with `minio` lands in LabUL. So the
name means the same MinIO wherever it is used, and the template can serve both
profiles. `minio-labda` with `management_cluster: machinery-labul` is refused
(that ProviderConfig does not exist there); the ClaimTemplate narrows the enum
the same way (`enumWhen`).

Defined in stuttgart-things: `clusters/labda/vsphere/machinery-fleet-state/`
`minio-labda.yaml` and `providerconfigs.yaml` (`minio`),
`clusters/labul/proxmox/machinery-labul-fleet-state/providerconfigs.yaml` (`minio`).

## Teardown: what is deleted

Crossplane itself only knows `deletionPolicy: Delete | Orphan` on a managed
resource. The XRD's `deletionPolicy` (`Orphan | DeleteIfEmpty | DeleteAll`) is
mapped by the Composition (crossplane-configurations
`storage/minio/apis/composition.yaml`) and provider-minio v0.4.5:

| XR `deletionPolicy` | composed `Bucket` | effect on deleting the XR |
|---|---|---|
| `Orphan` (default) | `deletionPolicy: Orphan`, no `bucketDeletionPolicy` | crossplane-runtime v1.18 `ShouldDelete()` is false → no external delete; the finalizer goes, **bucket and objects stay on the MinIO** |
| `DeleteIfEmpty` | `deletionPolicy: Delete`, `bucketDeletionPolicy: DeleteIfEmpty` | provider-minio `Delete()` (operator/bucket/delete.go) skips the object sweep (only `DeleteAll` runs it) and calls `RemoveBucket`. MinIO refuses a bucket with objects (`BucketNotEmpty`): the error keeps the finalizer, the Bucket MR stays and retries, **no object is deleted**. An empty bucket is removed |
| `DeleteAll` | `deletionPolicy: Delete`, `bucketDeletionPolicy: DeleteAll` | every object is removed, then the bucket. **This module refuses it**; write such an XR by hand |

In every case the Composition composes `Policy` and `User` with
`deletionPolicy: Delete`: they are access, not data, and go with the XR. The key
Secret (`default/<name>`) is the User's connection secret; crossplane-runtime
leaves it to Kubernetes garbage collection through its controller
ownerReference to the User, so it goes when the User is gone.

So after a teardown of an order with `DeleteIfEmpty` and an empty bucket
nothing is left: no bucket, no policy, no user, no Secret. With `Orphan` the
bucket (and its data) stays on the MinIO by design and has to be removed there
if it is really unwanted.

## Refusals

- `deletion_policy` other than `Orphan` / `DeleteIfEmpty` (`DeleteAll` named explicitly)
- `provider_config` other than `minio-labda` / `minio`, or not present on the management cluster
- `name` not 3-50 of `a-z0-9-` (S3 allows 63; 50 is machinery-order-service's limit for the order file name, so claims and the service accept the same names) starting and ending alphanumeric, or starting with `xn--` / `sthree-`
- an unknown management cluster without `source_path`

## Run

```bash
kcl run oci://ghcr.io/stuttgart-things/xr-minio-bucket --tag 0.1.0 \
  -D name=my-bucket -D requested_by=user:default/me -D order_id=ord-0123456789ab
```

## Tests

```bash
kcl test ./...
```

- `tests/golden_test.k`: renders against copies of hand-written XRs from
  stuttgart-things (`tests/testdata/`, verbatim at `132f474c5`):
  `labda-infra-zitadel-backup` and `labul-infra-zitadel-backup`
  (`minio-zitadel-backup.yaml`) and `homerun2-visuals` without its
  `bucketPolicy`. Identical except that the module writes the default
  `deletionPolicy: Orphan` and no `metadata.namespace` (the hand-written ones
  carry a `namespace: default` that a cluster-scoped XR ignores).
- `tests/refusals_test.k`: every refusal above, and the allowed combinations.
