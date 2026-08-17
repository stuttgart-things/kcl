# xplane-capability

`function-kcl` module for the **capability** Crossplane Configuration. Given a
namespaced `Capability` XR, it emits the objects that let a management cluster
act on an external system, onto a target cluster, one set per enabled capability:

| object | why |
|---|---|
| `ExternalSecret` (credentials) | the provider may log in |
| `ClusterProviderConfig` | it knows where to connect |
| `EnvironmentConfig` | it knows which node, datastore and template to place a VM on |
| `ExternalSecret` (workload) | only where a capability declares one — see below |

Structure comes from
[`xplane-capability-catalog`](../xplane-capability-catalog/); values come from
the XR.

## Why native rather than the Helm charts

The per-capability charts in `stuttgart-things/stuttgart-things` do the same
job. Two things get better in the move, and both follow from running *inside*
Crossplane rather than beside it.

**Two values stop being deploy-time parameters.** The charts take

```yaml
authMountPath: test-k3s-eso      # "appset injects <cluster>-eso per cluster"
secretStore.name: vault-cicd-proxmox-labul
```

Their own comment says the mount is injected from outside. Here the cluster name
is the XR's, so the same derivation happens where the fact lives.

**Package installation stays out.** The charts can install the Configuration and
the Provider, which is what their long comments about duplicate lock nodes are
about. That job belongs to the `management-plane` Configuration, which installs
packages under the CR names Crossplane itself derives — the shape in which the
[#247](https://github.com/stuttgart-things/crossplane-configurations/issues/247)
collision cannot occur.

**What does not move:** the `sops` and `sops-git` credential backends. They
exist so a cluster *without* Vault can still have credentials, and such a
cluster cannot use this module at all — it would get an `ExternalSecret` nothing
serves. For those clusters the charts remain the answer.

## The XR

```yaml
spec:
  clusterName: u26-rke2-1
  kubernetesProviderConfigRef: u26-rke2-1-kubernetes   # the TARGET cluster
  environment: labul              # defaults to clusterName; labels + names every object
  namespace: crossplane-system    # where the provider reads its Secret
  workloadNamespace: default      # where the VM XRs live
  capabilities:
    proxmoxvm:
      enabled: true
      vault:
        secret: default           # KV key; the store defaults to vault-cluster-secrets
      placement:
        node: ul-pve01
        datastore: V5010-01-1
        bridge: vmbrvlan
        vlanTag: "102"
        pool: stuttgart-things
        templateVmId: "211"
```

Everything not listed is either a catalog default or derived.
`providerConfigName` and `providerConfigKind` are **always** derived: they name
an object this module emits, and letting an XR state them would make it possible
to point a VM at a config this XR did not create.

## Two namespaces, not one

`namespace` is where the provider reads its credentials. `workloadNamespace` is
where the VM XRs live, and it is where a capability's *workload* secrets go —
the cloud-init password, for `proxmoxvm`. The namespaced `EnvironmentVM` CRD
resolves `passwordSecretRef` in the managed resource's own namespace, so a
cloud-init password placed next to the provider is a Secret nothing reads, and
the symptom is not a missing Secret: cloud-init applies its `lock_passwd`
default, LOCKS the guest account, and every password-based `AnsibleRun` reports
the host `UNREACHABLE`.

## Failing the render

A capability with a missing or unknown placement field aborts the whole render,
naming every problem across every capability at once.

```
capability configuration is incomplete: proxmoxvm: missing required placement ["node"]
```

Both halves are deliberate:

* **Missing** — a missing `node` does not surface as a validation error. It
  surfaces minutes later as a VM the provider tries to place nowhere, in a
  message that names the provider and not this XR.
* **Unknown** — a typo'd `templateVMID` would otherwise be dropped in silence,
  leave `templateVmId` missing, and produce an error naming the field the user
  did *not* write.
* **All at once** — a render is all-or-nothing, so reporting one field per
  reconcile is the difference between one round-trip and six.

An empty string counts as missing: an XRD default or a half-filled values file
arrives as `""`, which is exactly as unusable as absent for a node name.

## Invariants (`kcl test`)

Decisions live in `logic.k` so they can be tested without a Crossplane request;
`main.k` is plumbing. `validate` is a lambda rather than a module-level assert
for the same reason — a top-level assert fires during `kcl test` too, where
every field is legitimately absent.

| test | catches |
|---|---|
| `test_a_missing_required_field_is_named` | the silent-placement failure above |
| `test_a_typo_is_rejected_rather_than_dropped` | an unknown key vanishing |
| `test_an_empty_string_counts_as_missing` | `""` passing as a value |
| `test_defaults_apply_and_the_xr_wins` | a default that cannot be overridden — KCL treats a union over a schema-typed dict as a conflict, which would make overriding an error |
| `test_numbers_are_stringified` | `vlanTag: 102` failing the apply on type rather than content |
| `test_optional_fields_are_accepted_but_not_defaulted` | `cloneDatastore` acquiring a default. bpg's clone block is `ForceNew`: a value here rewrites the clone block of every VM already built under this EnvironmentConfig, and the provider answers with destroy + recreate |
| `test_every_capability_is_reported_in_one_pass` | one-error-per-reconcile |

## Naming

Objects are named `<capability>-<environment>`, credentials
`<capability>-creds-<environment>`. Two environments on one cluster (labda *and*
labul) must not share a `ClusterProviderConfig` or a Secret.

The credentials name deviates from the charts' `proxmox-creds-<env>` on purpose:
on a cluster that still has the chart installed, colliding would give one Secret
two owners and each ESO refresh would overwrite the other. Nothing else refers
to the name — only the `ClusterProviderConfig` this module also emits — so a
migration means deleting the chart's Secret, not renaming anything.
