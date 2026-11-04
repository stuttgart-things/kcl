# XR-NATIVE-VM

KCL module for VM orders on the native VM compositions
(`resources.stuttgart-things.com/v1alpha1`, crossplane-configurations
`vsphere-vm` / `proxmox-vm`).

It renders **the same order as the Backstage template `create-vm`**
(stuttgart-things/stuttgart-things `backstage/templates/create-vm`) for every
lab × use case. `hack/check-vm-kcl.py` in stuttgart-things renders both and
compares them, against the create-vm snapshots and the built orders as well
(stuttgart-things#4295). Change the order logic in both places, or the check
goes red.

| Lab (`templateName` / `lab`) | Kind | EnvironmentConfig | Factory (management cluster) | Orders directory |
|---|---|---|---|---|
| `labda-vsphere` | `NativeVsphereVM` | `labda` | `machinery` | `clusters/labda/vsphere/machinery-orders-xrs` |
| `labul-proxmox` (default) | `NativeProxmoxVM` | `labul` | `machinery-labul` | `clusters/labul/proxmox/machinery-labul-orders-xrs` |

## Output

A YAML stream:

1. the XR (`<name>-vm`), annotated with `management-cluster`, `source-path`
   (the file it belongs in), `requested-by`/`owner` when given, and
   `prune: disabled`
2. `dev` only: EnvironmentConfig `dev-machine-<name>` (dev-maintenance list),
   same file as the XR
3. `dev` only: ScrapeConfig `host-<name>` for the central Prometheus. Its own
   file: the annotation `stuttgart-things.com/target-path` names it
   (default `clusters/labda/vsphere/sthings-infra/monitoring/host-<name>.yaml`)

## Use cases

| `use_case` | Sizes | Plays after `sthings.baseos.setup` |
|---|---|---|
| `baseos` | all | – |
| `kind` | all | `sthings.container.kind` (`kind_workers`) |
| `dev` | large, xlarge | `sthings.baseos.dev`'s imports for the ticked `dev_features`, in its order; `sthings.baseos.node_exporter` last |
| `rke2` | medium and up | `sthings.rke.rke2_cluster`, single node via `inventoryGroups` |
| `github-runner` | large, xlarge | tool chain (`runner_toolchain`), `sthings.baseos.gh_runner`; `extraEnvSecretName: github-runner-token` |

The size rules, a wrong lab and an unknown use case are refusals (`assert`).
Every order carries the `sthings_build_*` markers; `sthings_build_source` is
`claim-machinery` unless `build_source` says otherwise.

## Sizes

| size | cpu | ram (MB) | disk (GB) |
|---|---|---|---|
| small | 2 | 4096 | 40 |
| medium | 4 | 8192 | 64 |
| large | 8 | 16384 | 100 |
| xlarge | 16 | 24576 | 200 |

`cpu`, `memory` and `disk` override the size individually.

## Parameters

The names are the create-vm form's (its render-order step's values), so the
form can switch its render step to claim-machinery-api unchanged.

| name | default | |
|---|---|---|
| `templateName` / `lab` | `labul-proxmox` | lab, see above |
| `name` | `demo-vm` | VM and hostname; the XR is `<name>-vm` |
| `size` | `medium` | small / medium / large / xlarge |
| `use_case` | `baseos` | baseos / kind / dev / rke2 / github-runner |
| `kind_workers` | `1` | kind |
| `dev_features` | all | dev; list or comma-separated; `[]` = none |
| `dev_go_version` | `1.27.3` | dev, feature go |
| `dev_kind_workers` | `3` | dev, feature kind |
| `dev_kind_name` | `dev` | dev, feature kind |
| `runner_labels` | – | github-runner, after `self-hosted,Linux,X64` |
| `runner_count` | `1` | github-runner |
| `runner_toolchain` | `true` | github-runner |
| `requested_by` | – | annotation `requested-by`; `identity: user` in the templates: claim-machinery-api with order auth sets it from the login (claim-machinery-api#122) |
| `owner` | `requested_by` | annotation `owner`; `identity: owner`: with order auth only the login or one of its groups (admins: any) |
| `order_id` | – | annotation `order-id` on every document, label on the XR |
| `management_cluster` | the lab's factory | annotation and build marker |
| `management_lab` | the factory's lab | build marker |
| `source_path` | `<orders directory>/<name>.yaml` | annotation `source-path` |
| `environment_config` | `labda` / `labul` | `spec.environmentConfig` |
| `claim_namespace` | `default` | |
| `monitoring_path` | see Output | dev's ScrapeConfig file |
| `build_source` | `claim-machinery` | `sthings_build_source` (the check passes `create-vm`) |
| `ansible` | `true` | `false` renders `ansible.enabled: false` |

The placement parameters (`management_cluster`, `management_lab`,
`source_path`, `environment_config`) are for an order service that places
orders itself (stuttgart-things#4296); their defaults are today's values.

A value counts as unset when it is missing or empty, so `kind_workers=0` and
`dev_features=[]` are kept. claim-machinery-api passes strings unquoted
(`-D key=value`), so a version like `1.30` arrives as the float `1.3`: send
three-part versions.

`managementCluster`, `environmentConfig` and `claimNamespace` (0.1.0) are
still read as aliases. 0.1.0's `playbooks` and `extraEnvSecretName` are gone:
the use case decides them.

## Run

```bash
kcl run oci://ghcr.io/stuttgart-things/xr-native-vm --tag 0.2.0 \
  -D templateName=labda-vsphere -D name=my-vm -D size=large -D use_case=dev \
  -D 'dev_features=["go","kind"]'
```

## Templates

- `templates/native-vm-labda-vsphere.yaml`
- `templates/native-vm-labul-proxmox.yaml`

Both list the same parameters; only the lab differs. Keep them in step.

## Schemas

`v1alpha1/` and `k8s/` are generated from the XRD's CRDs on machinery with
`kcl import -m crd` (status removed). The module type-checks the XR against
them but emits a plain dict, so schema defaults do not leak into the order.
