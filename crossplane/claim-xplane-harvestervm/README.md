# CLAIM-XPLANE-HARVESTERVM

KCL generator for `HarvesterVM` XRs targeting the **`harvester-vm` Crossplane
Configuration** (`stuttgart-things/crossplane-configurations` →
`machinery/harvester-vm`). Published as an OCI artifact to
`ghcr.io/stuttgart-things/claim-xplane-harvestervm`.

## What it emits

A single namespaced `HarvesterVM` (`resources.stuttgart-things.com/v1alpha1`,
Crossplane v2). The Configuration turns it into a Harvester / KubeVirt
`VirtualMachine` plus its root-disk PVC and cloud-init Secret.

## EnvironmentConfig model (the important bit)

Per-environment infrastructure is **not** baked into every XR. The XR carries a
`spec.environmentConfig` selector; the Composition loads a matching
`EnvironmentConfig` and supplies these fields from it:

| Field | Source |
|---|---|
| `spec.providerConfigRef` | EnvironmentConfig `providerConfigRef` |
| `spec.volume.storageClassName` | EnvironmentConfig `storageClassName` |
| `spec.volume.namespace` / `spec.cloudInit.namespace` | EnvironmentConfig `namespace` |
| `spec.volume.imageId` | EnvironmentConfig `imageId` |
| `spec.vm.networks[].networkName` | EnvironmentConfig `networkName` |

This generator emits those fields **only when you explicitly override them**, so
by default they inherit. Precedence is **XR spec → EnvironmentConfig → built-in
default**. This is why the Developer form asks for almost nothing.

## ClaimTemplate tiers

Three tiers drive the IDP/scaffolder form:

| Template | File | Prompts for |
|---|---|---|
| **Developer** | `templates/harvestervm-developer.yaml` | name, size, image |
| **Detailed** | `templates/harvestervm-detailed.yaml` | + hardened, login user, SSH key, extra packages, domain, environment |
| **Expert** | `templates/harvestervm-expert.yaml` | everything, incl. infra overrides and Ansible |

Everything not listed is inherited from the EnvironmentConfig or hidden behind a
sane default.

## T-shirt sizes

`size` drives CPU cores, memory, the CPU resource string and the root-disk size.

| Size | Cores | Memory | Storage |
|------|-------|--------|---------|
| S | 2 | 2Gi | 20Gi |
| M | 4 | 4Gi | 40Gi |
| L | 8 | 8Gi | 80Gi |
| XL | 16 | 16Gi | 160Gi |
| XXL | 32 | 32Gi | 320Gi |

Expert users can override `cores` / `memory` / `cpuResource` / `storage`
directly; an explicit value wins over the size.

## `hardened`

A single boolean instead of separate `demo`/`production` templates:

| | `hardened: false` (default) | `hardened: true` |
|---|---|---|
| `packageUpgrade` | false | true |
| `sshPasswordAuth` | true | false |
| `disableRoot` | false | true |

`packageUpdate` is always on. Expert users can still override each of
`packageUpgrade` / `sshPasswordAuth` / `disableRoot` individually.

## Images

`image` picks a base-image alias. The default `inherit` omits
`spec.volume.imageId` so the **EnvironmentConfig image** is used — the
recommended path. Pick a specific alias only when you need a different image
than the environment default.

| Alias | OS |
|---|---|
| `inherit` | use the EnvironmentConfig image (default) |
| `ubuntu25` | Ubuntu 25.04 |
| `ubuntu22` | Ubuntu 22.04 LTS |
| `rocky9` | Rocky Linux 9 |
| `rocky8` | Rocky Linux 8 |
| `debian12` | Debian 12 |
| `opensuse15` | openSUSE Leap 15 |
| `opensuse-micro` | openSUSE MicroOS |

> **Image ids are environment-specific.** Harvester assigns an id on upload
> (`kubectl -n <ns> get virtualmachineimages`). The alias→id map in `main.k`
> (`_imageCatalog`) and these enums are a single source of truth that you must
> reconcile with your Harvester before relying on a non-`inherit` alias. The
> storage class is **not** synthesised from the image — it is inherited from the
> EnvironmentConfig (or set explicitly in the Expert tier).

For full control, Expert exposes a direct `imageId`
(`namespace/image-xxxx`) that wins over both the alias and the environment.

## Boot disk

Defaults to `accessModes: [ReadWriteOnce]`, `volumeMode: Block`. A RWX Block
boot volume risks a second instance attaching the same disk (corruption with
`RerunOnFailure`); use RWX only for multi-node live-migration. This matches
`crossplane-configurations#32`.

## Multiple VMs

`count` is **not** implemented here — render once per VM (each VM gets its own
name, PVC and cloud-init Secret) rather than emitting a list from one claim.

## Usage

```bash
# Developer: inherit all infrastructure from the environment
kcl run . -D name=dev9 -D size=L

# Pick an image and harden the OS
kcl run . -D name=dev9 -D size=M -D image=ubuntu25 -D hardened=true

# Expert: override infra + add SSH access + Ansible
kcl run . -D name=db01 -D size=XL \
  -D providerConfigRef=harvester -D storageClassName=harvester-longhorn \
  -D targetNamespace=vms -D networkName=default/vms \
  -D sshKey="ssh-rsa AAAA..." -D ansibleEnabled=true
```

### From the OCI registry

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-harvestervm --tag 0.2.0 \
  -D name=my-vm -D size=M
```

## Parameters

| Param | Default | Notes |
|---|---|---|
| `name` | `harvester-vm` | VM / XR name |
| `namespace` | `default` | namespace the XR object lives in |
| `environmentConfig` | `default` | EnvironmentConfig selector |
| `size` | `M` | t-shirt size |
| `image` | `inherit` | base-image alias |
| `hardened` | `false` | OS hardening toggle |
| `user` | `sthings` | primary cloud-init user |
| `sshKey` | – | SSH public key for the user |
| `packages` | `[]` | extra packages (qemu-guest-agent always included) |
| `domain` | `local` | cloud-init domain |
| `timezone` | `Europe/Berlin` | cloud-init timezone |
| `cores` / `memory` / `cpuResource` / `storage` | from `size` | explicit overrides |
| `pvcName` | `<name>-disk-0` | root disk PVC name |
| `accessModes` / `volumeMode` | `[ReadWriteOnce]` / `Block` | boot disk |
| `providerConfigRef` | inherit | env override |
| `storageClassName` | inherit | env override |
| `targetNamespace` | inherit | env override (PVC / Secret / VM namespace) |
| `networkName` | inherit | env override (Multus network) |
| `imageId` | inherit | direct id override |
| `os` / `machineType` / `runStrategy` / `evictionStrategy` | `ubuntu` / `q35` / `RerunOnFailure` / `LiveMigrateIfPossible` | VM settings |
| `packageUpgrade` / `sshPasswordAuth` / `disableRoot` | from `hardened` | individual overrides |
| `ansibleEnabled` | `false` | emit an AnsibleRun after the VM is up |

## Requirements

- KCL v0.11.2+
- The `harvester-vm` Configuration installed on the cluster, plus a matching
  `EnvironmentConfig` (label
  `harvester-vm.resources.stuttgart-things.com/environment=<environmentConfig>`)
  and the `ClusterProviderConfig` it references.
- A Harvester cluster with the base images uploaded.
