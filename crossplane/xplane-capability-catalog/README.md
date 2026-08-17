# xplane-capability-catalog

Structural definitions of the **capabilities** a management cluster can be given.

A capability is what lets a cluster act on an external system. The provider is
installed on every management cluster, but on its own it does nothing useful:

| missing | consequence |
|---|---|
| `ClusterProviderConfig` | the provider runs and does not know where to connect |
| credentials | it knows where, and may not log in |
| `EnvironmentConfig` | it is logged in and does not know which node, datastore or template to place a VM on |

This module says what each capability's three objects look like.
[`xplane-capability`](../xplane-capability/) renders them onto a target cluster
from a `Capability` XR.

## What belongs here — and what does not

Structural facts only: which `ClusterProviderConfig` kind a provider reads, how
one Vault KV secret maps into the credential payload it expects, which placement
fields exist, and which of them have fleet-wide defaults.

VALUES do not. `node: ul-pve01`, `templateVmId: "211"`, the Vault path — those
are per-cluster and belong on the XR. Same split as
[`xplane-flux-catalog`](../xplane-flux-catalog/), for the same reason: a value
copied here drifts from the environment that owns it, silently, because nothing
compares them.

The dividing question is not "does it change often" but "who owns it". `virtio0`
is a default here even though it never changes, because it is a property of the
sthings-u26 image and the bpg provider — not of LabUL.

## Entries

| capability | provider config | Vault keys | required placement |
|---|---|---|---|
| `ansible` | **none** | `vm_ssh_user`, `vm_ssh_password` | `namespace`, `storageClass` |
| `proxmoxvm` | `proxmoxbpg.m.crossplane.io/v1beta1` | `pve_api_url`, `pve_api_user`, `pve_api_password`, `vm_ssh_user`, `vm_ssh_password` | `node`, `datastore`, `bridge`, `vlanTag`, `pool`, `templateVmId` |
| `vspherevm` | `vspherevm.m.stuttgart-things.com/v1beta1` | `vsphere_user`, `vsphere_password`, `vsphere_server` | `templateUuid`, `datastoreId`, `resourcePoolId`, `networkId`, `folder`, `domain` |

`ansible` is the entry that made the schema earn its keep, and it differs from
the other two in all three ways a capability can:

* **no provider config** — it configures a Configuration, not a provider.
  `providerConfig?` was optional from the first version for exactly this.
* **two plain credential keys** instead of one JSON document, because the
  consumer is a Tekton pipeline reading environment variables.
* **a list-valued default.** `ansibleExtraCollections` reaches Tekton as a
  parameter, and a stringified list is rejected there with
  `ParameterTypeMismatch` — an error that names the Tekton parameter and
  nothing about where the value came from. So `defaults` is `{str:any}`, and a
  consumer must not coerce.

Both were transcribed from the capability Helm charts in
`stuttgart-things/stuttgart-things` (`crossplane/platform/capabilities/`), which
are the shapes the `proxmoxvm` and `vspherevm` Compositions already read.
Deviating from those field names would not be a redesign — the Compositions look
them up by name, so it would be a silent break.

## Three fields, three kinds of ownership

```kcl
required = ["node", "datastore", ...]   # facts about a datacenter; nothing can derive them
defaults = {diskInterface = "virtio0"}  # facts about the image and the provider; an XR value wins
optional = ["cloneDatastore", ...]      # emitted only when stated, and one of them bites
```

`cloneDatastore` is why `optional` exists as its own list rather than being a
default with an empty value. bpg's clone block is `ForceNew`: a value appearing
on an `EnvironmentConfig` rewrites the clone block of every VM already built
under it, and the provider answers with destroy + recreate — unattended, under
`compositionUpdatePolicy: Automatic`.

## Workload secrets

`proxmoxvm` declares one. It is not a credential for the provider; it is the
cloud-init password, and it lives in the namespace where the VM XRs are, because
the namespaced `EnvironmentVM` CRD resolves `passwordSecretRef` in the managed
resource's own namespace.

Skipping it is the kind of omission that hides. Without a `cipassword` in the
user-data Proxmox emits, cloud-init applies its `lock_passwd` default and LOCKS
the guest account on first boot, discarding what the Packer build baked in. Key
logins keep working, so the cluster looks healthy — what breaks is every
password-based `AnsibleRun`, each host simply `UNREACHABLE`.

## Invariants (`kcl test`)

| test | catches |
|---|---|
| `test_declared_vault_keys_match_the_templates` | a typo'd Vault key. ESO renders a missing key as the empty string, so the provider gets a syntactically valid credential that does not authenticate |
| `test_workload_secret_vault_keys_match_their_templates` | the same, one level worse: an empty password locks the guest account and the cluster still comes up |
| `test_provider_capabilities_ship_a_single_credentials_key` | a per-field Secret. The bpg and vsphere providers parse ONE JSON document out of ONE key |
| `test_tls_flags_are_json_strings` | `"insecure": true`. The field unmarshals into a string, and a bare boolean fails the parse naming neither field nor Secret |
| `test_provider_config_groups_are_namespaced_variants` | the cluster-scoped CRD instead of the namespaced `.m.` one — "no matches for kind" at apply time |
| `test_environment_label_is_capability_scoped` | a label the consuming Composition does not select on |
| `test_fields_are_disjoint` | a placement field in two lists, where the emitted value would be arbitrary |
| `test_workload_secrets_are_referenced_from_placement` | a workload Secret nothing reads |

## Adding a capability

1. `capabilities/<name>.k` — one `s.Capability`, transcribed from the consuming
   Composition's field names, not invented.
2. Register it in `main.k`.
3. `kcl test` — the invariants above apply to it automatically.

## Not covered

The `sops` and `sops-git` credential backends the Helm charts offer. Those exist
so a cluster **without** Vault can still have credentials, and such a cluster
cannot use this catalog's consumer at all — it would get an `ExternalSecret`
nothing serves. For those clusters the charts remain the answer.
