"""
Structural definitions for the stuttgart-things capability catalog.

A *capability* is what lets a cluster act on an external system: the provider
runs, but without a ClusterProviderConfig it does not know where; without
credentials it may not log in; without an EnvironmentConfig it does not know
which node, datastore or template to place a VM on.

Holds STRUCTURAL facts only — which ClusterProviderConfig kind a provider reads,
how one Vault KV secret maps into the credential payload it expects, which
placement fields exist and which of them have fleet-wide defaults. VALUES
(node, datastore, templateVmId, the Vault path) are per-cluster and belong on
the XR. Same split as xplane-flux-catalog, for the same reason: a value copied
here drifts from the environment that owns it.
"""

schema ProviderConfig:
    """
    The provider's own config object.

    Optional on a capability: `ansible` configures a Configuration rather than a
    provider and has none, while `proxmoxvm` cannot place a single VM without
    one.
    """
    apiVersion: str
    """Full apiVersion of the provider's ClusterProviderConfig CRD, e.g.
    'proxmoxbpg.m.crossplane.io/v1beta1'. Providers do NOT share a group, and
    the namespaced (`.m.`) variants are separate CRDs from the cluster-scoped
    ones — see CLAUDE.md."""

    kind: str = "ClusterProviderConfig"

    credentialsKey: str = "credentials"
    """Key WITHIN the Secret the provider reads. For the bpg and vsphere
    providers this is a single key holding a JSON document, not one key per
    field."""

schema Credentials:
    """
    How one Vault KV-v2 secret becomes the Secret a capability consumes.

    `data` values are ESO templates (engineVersion v2) evaluated against the
    keys of the extracted Vault secret, so `{{ .pve_api_url }}` refers to the
    Vault key `pve_api_url`. They are stored as opaque strings here: this module
    never renders them, it only decides which capability gets which shape.
    """
    data: {str:str}
    """Target Secret key -> ESO template."""

    vaultKeys: [str]
    """Vault keys the templates reference. Redundant with `data` by
    construction, and that is the point: a missing key renders as the empty
    string rather than failing, so a provider gets a syntactically valid
    credential that simply does not authenticate. Declaring them lets a test
    catch a typo that Vault would only reveal at first login."""

    check:
        len(data) > 0, "a capability with no credential data has nothing to authenticate with"
        len(vaultKeys) > 0, "declare the Vault keys the templates read"

schema WorkloadSecret:
    """
    A second Secret the capability needs, in the namespace where the XRs live
    rather than where the provider reads its credentials.

    Only proxmoxvm has one, and skipping it is the kind of omission that hides:
    without a cipassword in the user-data Proxmox emits, cloud-init applies its
    `lock_passwd` default and LOCKS the guest account on first boot, discarding
    what the Packer build baked in. Key logins keep working, so the cluster
    looks fine — what breaks is every password-based AnsibleRun, each host
    simply UNREACHABLE.
    """
    nameSuffix: str
    """Appended to the capability name: 'ci-password' -> 'proxmoxvm-ci-password'."""

    data: {str:str}
    """Target Secret key -> ESO template, same rules as Credentials.data."""

    vaultKeys: [str]

    check:
        len(data) > 0, "a workload secret with no data is not worth an object"

schema Capability:
    """One capability: provider config + credentials + placement facts."""
    name: str
    """Catalog key. Also the default prefix for every emitted object name."""

    providerConfig?: ProviderConfig
    credentials: Credentials

    environmentLabelKey: str
    """Label key on the emitted EnvironmentConfig. The consuming Composition
    selects on it, so it is part of the contract with that Configuration and NOT
    free-form — proxmoxvm reads
    `proxmoxvm.resources.stuttgart-things.com/environment`."""

    required: [str]
    """Placement fields the XR MUST supply. Facts about a datacenter that
    nothing can derive: which node, which datastore, which template."""

    defaults: {str:str} = {}
    """Placement fields with a fleet-wide default. An XR value always wins.
    These are here rather than on the XR because they are properties of the
    IMAGE and the provider, not of the environment: sthings-u26 puts its root
    disk on virtio0, and getting that wrong produces a VM that boots to no
    disk."""

    workloadSecrets: [WorkloadSecret] = []
    """Secrets that belong in the workload namespace rather than beside the
    provider. See WorkloadSecret."""

    optional: [str] = []
    """Placement fields that are neither required nor defaulted — emitted only
    when the XR sets them. `cloneDatastore` is the cautionary one: bpg's clone
    block is ForceNew, so a value appearing on an EnvironmentConfig rewrites the
    clone block of every VM already built under it, and the provider answers
    with destroy + recreate."""

    check:
        len(required) > 0, "a capability with no required placement fields is a defaults bundle, not a capability"
        len([k for k in defaults if k in required]) == 0, "a field cannot be both required and defaulted"
        len([k for k in optional if k in required or k in defaults]) == 0, "optional fields must not repeat required or defaulted ones"

