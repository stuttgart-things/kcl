# xplane-capability

`function-kcl` module for the **capability** Crossplane Configuration. Given a
namespaced `Capability` XR, it emits the objects that let a management cluster
act on an external system, onto a target cluster, one set per enabled capability:

| object | why |
|---|---|
| `Namespace` | the ones this module writes into, so they are not a precondition — see below |
| `ClusterSecretStore` | where the credentials come from — only where a capability names its own KV mount |
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
is the XR's, so `<clusterName>-eso` is derived where the fact lives — which is
only true because this module emits the store itself. A capability that borrowed
an existing store would leave that derivation to whoever created it.

**One store per capability, and that is not a choice.** A `ClusterSecretStore`
fixes ONE Vault KV mount, and capabilities do not share one: proxmox credentials
live under `cicd-proxmox-labul`, vsphere under its own. So a capability names
its `mount` and gets a store; everything else about that store — server, CA,
auth mount, role, ServiceAccount — is a property of the cluster and is stated
once, or derived.

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
  vault:
    server: https://vault.infra.sthings-vsphere.labul.sva.de
    # auth.mountPath defaults to <clusterName>-eso, role to eso, the
    # ServiceAccount to external-secrets/external-secrets, and the CA to
    # vault-pki-ca in cert-manager — the shape the platform's external-secrets
    # app already produces.
  namespace: crossplane-system    # where the provider reads its Secret
  workloadNamespace: default      # where the VM XRs live
  capabilities:
    proxmoxvm:
      enabled: true
      vault:
        mount: cicd-proxmox-labul # KV-v2 mount -> this capability gets its own store
        secret: default           # KV key within it
      placement:
        node: ul-pve01
        datastore: V5010-01-1
        bridge: vmbrvlan
        vlanTag: "102"
        pool: stuttgart-things
        templateVmId: "211"
```

Everything not listed is either a catalog default or derived.
`providerConfigName`, `providerConfigKind`, `ciPasswordSecretName` and (for
`ansible-run`) `ansibleCredentialsSecretName` are **always** derived: each names an
object this module emits, and letting an XR state one makes it possible to point
a consumer at something this XR did not create — or at a name that does not
exist, which reads as a missing credential rather than a wrong name.

## Three namespaces, not one

Where a Secret goes is decided per capability, because a Secret in the wrong
namespace does not fail — it is simply never read, and the consumer reports a
*missing* credential while pointing at itself.

| Secret | namespace | who reads it |
|---|---|---|
| credentials (default) | `spec.namespace` | the provider, beside itself |
| credentials (`credentialsNamespaceField`) | a placement value | `ansible-run`: the Tekton pipeline, in its own namespace |
| workload | `spec.workloadNamespace` | the VM XR — see below |

## Two namespaces, not one

`namespace` is where the provider reads its credentials. `workloadNamespace` is
where the VM XRs live, and it is where a capability's *workload* secrets go —
the cloud-init password, for `proxmoxvm`. The namespaced `EnvironmentVM` CRD
resolves `passwordSecretRef` in the managed resource's own namespace, so a
cloud-init password placed next to the provider is a Secret nothing reads, and
the symptom is not a missing Secret: cloud-init applies its `lock_passwd`
default, LOCKS the guest account, and every password-based `AnsibleRun` reports
the host `UNREACHABLE`.

## The namespaces are created, not assumed

Every namespace in the table above is emitted as a `Namespace` object with
`managementPolicies: [Observe, Create]` — adopt it if it exists, create it if it
does not, never modify or delete it.

It has to be this module, because *which* namespace it is comes out of a
capability's own placement. `ansible-run` puts its credentials in `tekton-ci`
because a Tekton pipeline reads them there. On `u26-rke2-1` that namespace
existed, because that cluster's Platform installs the `tekton` app; on
`seed-labda-1`, which runs only cert-manager, external-secrets and openebs, the
object sat at

```
create failed: cannot create object: namespaces "tekton-ci" not found
```

with the `vspherevm` half of the same XR green — a capability held up by a
precondition nothing declared.

Two consequences of the policy set:

* **no `Delete`** — the namespace and everything in it survives the capability
  being torn down. With `Delete`, switching off `ansible-run` would take the
  cluster's Tekton pipelines with it.
* **no `Update`** — a namespace that already has an owner (the `tekton` app,
  another Capability XR, a human) keeps it. Two Capability XRs may name the same
  namespace and neither writes to it.

No exception list, so `default` and `crossplane-system` are emitted too. They are
adopted on the first observe and never touched again; a list of "these always
exist" would be Kubernetes trivia in the module with exactly one hole in it — the
day someone points `spec.namespace` at something of their own.

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
| `test_list_values_are_not_stringified` | `ansibleExtraCollections` reaching Tekton as a string — rejected there with `ParameterTypeMismatch`, an error naming the Tekton parameter and nothing about where the value came from |
| `test_credentials_land_where_their_consumer_reads_them` | a credentials Secret beside the provider when a pipeline elsewhere reads it |
| `test_a_store_without_a_server_is_rejected` | a store with nothing left to derive |
| `test_an_existing_store_needs_no_vault_facts` | requiring Vault facts from a cluster that reuses a store it already trusts |
| `test_status_less_objects_do_not_derive_readiness_from_themselves` | an EnvironmentConfig or ClusterProviderConfig stuck at Ready=False forever |
| `test_secret_objects_derive_readiness_from_themselves` | a capability reporting ready while Vault answers 403 |
| `test_the_credentials_namespace_is_ensured` | the `tekton-ci` failure above coming back |
| `test_a_shared_namespace_is_emitted_once` | two capabilities naming one namespace producing two composed objects with the same name — a render error that appears only when someone enables the second capability |
| `test_namespaces_come_out_in_a_stable_order` | a render that changes with dict iteration, which every differ reads as a change |
| `test_an_empty_namespace_is_dropped` | `namespace: ""` reaching the API server as an empty `metadata.name` |

## Readiness

Not one policy for all of them.

| object | policy | why |
|---|---|---|
| `ClusterSecretStore` | `DeriveFromObject` | its `Valid` condition IS the proof that the Vault login works |
| `ExternalSecret` | `DeriveFromObject` | its `Ready` condition is the only signal that Vault answered — a capability whose credentials 403 must not report ready |
| `EnvironmentConfig` | `DeriveFromCelQuery` (`true`) | it has no conditions at all |
| `Namespace` | `DeriveFromCelQuery` (`true`) | same — no conditions, only `status.phase` |
| `ClusterProviderConfig` | `DeriveFromCelQuery` (`true`) | same, and measured: [#294](https://github.com/stuttgart-things/crossplane-configurations/issues/294) found `SuccessfulCreate` never evaluated and `AllTrue` false on an empty condition list |

Using `DeriveFromObject` everywhere leaves the two status-less objects at
`Ready=False` forever while what they created is present and correct — found on
`u26-rke2-1` on the first live apply.

## Naming

Objects are named `<capability>-<environment>`, credentials
`<capability>-creds-<environment>`. Two environments on one cluster (labda *and*
labul) must not share a `ClusterProviderConfig` or a Secret.

The store is named `<capability>-<environment>` rather than the charts'
`vault-<mount>`, and the credentials name deviates from their
`proxmox-creds-<env>`, both on purpose:
on a cluster that still has the chart installed, colliding would give one Secret
two owners and each ESO refresh would overwrite the other. Nothing else refers
to the name — only the `ClusterProviderConfig` this module also emits — so a
migration means deleting the chart's Secret, not renaming anything.
