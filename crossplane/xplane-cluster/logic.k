"""
Resource construction for the ClusterStack XR.

Pure functions only — everything here takes explicit arguments and returns a
dict, so it can be unit-tested without Crossplane, a cluster, or an ocds map.
main.k does the wiring: it reads option("params"), decides which stages are
open, and calls these.

The build order is:

    VM (+ base-OS ansible)  ->  distribution run  ->  kubeconfig upload
                            ->  ClusterAccess     ->  Platform

Each stage is gated on the previous one having actually SUCCEEDED, and every
gate is sticky (see main.k): once a child exists it keeps being emitted, because
not emitting a composed resource is what makes Crossplane delete it — and a
deleted, recreated AnsibleRun re-runs its play against a live machine.
"""

import xplane_cluster_catalog as cat

# --- small helpers ---------------------------------------------------------

# The ansible-run XR takes vars as "key+-value" strings; the catalog holds them
# as a map so a consumer can override one entry without restating the set.
renderVars = lambda vars: {str:str} -> [str] {
    ["{}+-{}".format(k, v) for k, v in vars]
}

# Inventory in the ansible-run `group+[...]` syntax. The FIRST group gets the
# host; the rest are emitted present-but-empty.
#
# Empty groups are not decoration: sthings.rke.deploy_configure_rke branches on
# `groups['initial_master_node']` and `groups['additional_master_nodes']`, so a
# flat `all+[...]` inventory fails with an undefined-group error. Header-only
# INI sections register as existing-but-empty, which is what the role's
# `in groups[...]` tests need.
renderInventory = lambda groups: [str], ip: str -> [str] {
    # No enumerate() in KCL — index by position against the first element.
    [('{}+["{}"]'.format(g, ip) if g == groups[0] else "{}+[]".format(g)) for g in groups]
}

# Every varsFile entry that must carry the cluster name, for EVERY stage.
#
# `cluster_name` alone is not enough and never was: sthings.container.kind does
# not read it — it names the cluster from `kind_cluster_name` and otherwise uses
# the play's own default, `dev`. So a ClusterStack for `kindstack-test` built a
# kind cluster called `dev`, and the Platform's Cni child pointed cilium at
# `kindstack-test-control-plane`, a container that does not exist. With
# kubeProxyReplacement that deadlocks rather than degrades: the 10.96.0.1 VIP is
# not programmed until cilium is up, so there is no fallback path to the API
# (crossplane-configurations#232).
#
# APPLIED TO BOTH STAGES, deliberately. upload_kubeconfig_vault derives
# kubeconfig_path from `kind_cluster_name` too, and before this both plays
# defaulted to `dev` and therefore agreed by accident — setting the name in the
# distribution stage only would have broken a working upload.
#
# WHICH keys is a catalog fact (Distribution.clusterNameVars), not a branch on
# the distribution name here: the consumer states "the name goes everywhere it
# is read", the catalog states where that is.
clusterNameVars = lambda distribution: str, cluster: str -> [str] {
    ["{}+-{}".format(k, cluster) for k in ["cluster_name"] + cat.getDistribution(distribution).clusterNameVars]
}

# Per-stage ansible overrides. `ansible.extraCollections` is the shared list; a
# stage entry is MERGED OVER it rather than replacing it, so the common case
# stays a single list.
#
# Why per stage at all: the shared list is passed to every run, so pinning one
# collection for the base-OS stage silently replaced the default set for the k3s
# stage too. On the first live build that meant restating sthings-rke — needed
# only by the distribution stage — in order to bump sthings-baseos, needed only
# by the base-OS stage.
stageAnsible = lambda spec: {str:any}, stage: str -> {str:any} {
    _ans = spec?.ansible or {}
    _stages = _ans?.stages or {}
    _over = _stages[stage] if stage in _stages else {}
    _shared = {k: v for k, v in _ans if k not in ["stages"]}

    # KCL's `|` UNIFIES, it does not override: a key holding a list on BOTH
    # sides is a conflict ("conflicting values on the attribute ..."), not a
    # replacement. Drop the overridden keys from the shared side first, so the
    # union has nothing to conflict about. Unit tests with literal dicts did not
    # catch this — it only surfaced rendering a real XR.
    {k: v for k, v in _shared if k not in _over} | _over
}

# --- the VM child ----------------------------------------------------------

# provider -> the kind vmChild emits for it. Lives here rather than in main.k
# because it is the same fact the `if _provider ==` chain below encodes, and
# because `groupOf` is checked against it: a provider added to this map without
# a group entry is a compile error, not a Usage that guards nothing.
#
# An unknown or absent provider is proxmox, matching vmChild's `else` branch.
vmKindOf = {
    "proxmox" = "NativeProxmoxVM"
    "vsphere" = "NativeVsphereVM"
    "harvester" = "HarvesterVM"
}

vmKind = lambda provider: str -> str {
    vmKindOf[provider] or vmKindOf["proxmox"]
}

vmChild = lambda name: str, ns: str, spec: {str:any}, size: any -> {str:any} {
    _provider = spec?.provider or "proxmox"
    _cluster = spec?.clusterName or name
    _vm = spec?.vm or {}
    _ans = stageAnsible(spec, "baseos")

    # Base-OS stage. vm_hostname is not cosmetic on Proxmox: bpg cloud-init
    # cannot set the guest hostname without a snippets datastore, so
    # sthings.baseos.setup does it from this var.
    # setHostname defaults TRUE, but is a knob rather than a hard-wire: the var
    # needs sthings-baseos >= 26.5.695, and on an older collection set it is
    # SILENTLY IGNORED — the guest simply keeps the template hostname with no
    # error anywhere. A fleet still on an older pin can turn it off and know why
    # the hostname is not set, instead of wondering.
    _setHostname = _ans?.setHostname if "setHostname" in _ans else True
    _hostnameVars = ["vm_hostname+-{}".format(_cluster)] if _setHostname else []
    _baseVars = [
        "manage_filesystem+-true"
        "update_packages+-true"
    ] + _hostnameVars + (_ans?.extraVars or [])

    _ansible = {
        enabled = True
        playbooks = ["sthings.baseos.setup"]
        varsFile = _baseVars
        crossplaneProviderConfig = _ans?.crossplaneProviderConfig or "in-cluster"
        pipelineNamespace = _ans?.pipelineNamespace or "tekton-ci"
        if _ans?.extraCollections:
            extraCollections = _ans.extraCollections
        if _ans?.ansibleWorkingImage:
            ansibleWorkingImage = _ans.ansibleWorkingImage
    }

    _common = {
        metadata = {
            name = "{}-vm".format(name)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "vm"}
        }
    }

    # vsphere and proxmox differ only in FIELD NAMES; staging, gating and
    # everything downstream are identical (crossplane-configurations#168,
    # option A). Harvester breaks that symmetry and is therefore written out in
    # full rather than folded into the others:
    #
    #   - the boot disk is a PVC of its own (`volume`), not a `disk` field
    #   - cpu is an OBJECT (cores/sockets/threads), and the scheduler wants a
    #     separate `resources.cpu` string on top of it
    #   - memory is a quantity string, not a number of MiB
    #   - cloud-init is a first-class block with a REQUIRED vmName/hostname
    #   - ansible.enabled defaults to FALSE there, so the base-OS stage has to
    #     be switched on explicitly or the cluster never gets provisioned
    #
    # Sizes are strings in the catalog (cpu "4", memory "8192" MiB, disk "64"
    # GiB); the suffixes below are what turns them into Kubernetes quantities.
    _res = {
        if _provider == "harvester":
            apiVersion = "resources.stuttgart-things.com/v1alpha1"
            kind = "HarvesterVM"
            spec = {
                environmentConfig = spec?.environmentConfig or "labul"
                volume = {
                    pvcName = "{}-disk-0".format(_cluster)
                    storage = "{}Gi".format(size.disk)
                    if _vm?.imageId:
                        imageId = _vm.imageId
                }
                cloudInit = {
                    vmName = _cluster
                    hostname = _cluster
                }
                vm = {
                    cpu.cores = int(size.cpu)
                    resources = {
                        cpu = size.cpu
                        memory = "{}Mi".format(size.memory)
                    }
                }
                # NOT optional: the XRD defaults this to false, and without it
                # the VM comes up bare -- no base OS, no kubernetes, and the
                # ClusterStack waits forever on a stage that was never emitted.
                ansible = _ansible | {enabled = True}
            }
        elif _provider == "vsphere":
            apiVersion = "resources.stuttgart-things.com/v1alpha1"
            kind = "NativeVsphereVM"
            spec = {
                environmentConfig = spec?.environmentConfig or "labul"
                vm = {
                    name = _cluster
                    cpu = size.cpu
                    ram = size.memory
                    disk = size.disk
                    if _vm?.templateUuid:
                        templateUuid = _vm.templateUuid
                }
                ansible = _ansible
            }
        else:
            apiVersion = "resources.stuttgart-things.com/v1alpha1"
            kind = "NativeProxmoxVM"
            spec = {
                environmentConfig = spec?.environmentConfig or "labul"
                vm = {
                    name = _cluster
                    cpu = size.cpu
                    memory = size.memory
                    disk = size.disk
                    if _vm?.templateVmId:
                        templateVmId = _vm.templateVmId
                }
                cloudInit = {
                    ipv4Address = _vm?.ipv4Address or "dhcp"
                }
                ansible = _ansible
            }
    }
    _res | _common
}

# --- the two ansible stages ------------------------------------------------
# Per-stage re-run IDs. NOT one global runID: bumping that renamed EVERY stage,
# so repairing the kubeconfig upload also re-ran the k3s install against a live
# cluster — observed on the first live build, and exactly the hazard the fleet's
# hand-written XRs warn about in their headers. A re-run has to name its stage.
#
# The base-OS stage is deliberately absent: it runs from the VM XR's own
# spec.ansible, whose XRD has no runID, so it is not expressible from here.
runIDFor = lambda spec: {str:any}, stage: str -> str {
    _ids = spec?.runIDs or {}
    str(_ids[stage]) if stage in _ids else ""
}

_ansibleRun = lambda name: str, ns: str, stage: str, spec: {str:any}, playbooks: [str], vars: [str], inventory: [str], vaultSecret: str, extraEnvSecret: str -> {str:any} {
    _ans = stageAnsible(spec, stage)
    _runID = runIDFor(spec, stage)
    _suffix = "-{}".format(_runID) if _runID else ""
    _runName = "{}-{}{}".format(name, stage, _suffix)
    {
        apiVersion = "resources.stuttgart-things.com/v1alpha1"
        kind = "AnsibleRun"
        metadata = {
            name = "{}-{}".format(name, stage)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = stage}
        }
        spec = {
            pipelineRunName = _runName
            namespace = _ans?.pipelineNamespace or "tekton-ci"
            ansiblePlaybooks = playbooks
            ansibleVarsFile = vars
            ansibleVarsInventory = inventory
            crossplaneObjectName = _runName
            crossplaneNamespace = ns
            crossplaneProviderConfig = _ans?.crossplaneProviderConfig or "in-cluster"
            # Emitted only when non-empty, so the distribution run's params stay
            # byte-identical to before this field existed.
            if vaultSecret:
                vaultSecretName = vaultSecret
            # The Rancher join reads its registration command from the
            # environment, not from varsFile: the command carries a token, and
            # varsFile lands in a ConfigMap. Empty for every other stage, so
            # their params stay byte-identical.
            if extraEnvSecret:
                extraEnvSecretName = extraEnvSecret
            if _ans?.extraCollections:
                ansibleExtraCollections = _ans.extraCollections
            if _ans?.extraCollections:
                installExtraCollections = "true"
            if _ans?.ansibleWorkingImage:
                ansibleWorkingImage = _ans.ansibleWorkingImage
        }
    }
}

distributionRun = lambda name: str, ns: str, spec: {str:any}, ip: str -> {str:any} {
    _cluster = spec?.clusterName or name
    _dist = cat.getDistribution(spec?.distribution or "k3s")
    _vars = renderVars(_dist.vars) + clusterNameVars(spec?.distribution or "k3s", _cluster) + (stageAnsible(spec, "distribution")?.extraVars or [])
    _ansibleRun(name, ns, "distribution", spec, _dist.playbooks, _vars, renderInventory(_dist.inventoryGroups, ip), "", "")
}

kubeconfigRun = lambda name: str, ns: str, spec: {str:any}, ip: str -> {str:any} {
    _cluster = spec?.clusterName or name
    _stage = cat.kubeconfigStage

    # Where the kubeconfig sits on the node differs per distribution, and the
    # upload play cannot guess: its default is
    # `/home/{{ ansible_user }}/.kube/{{ kind_cluster_name }}` — a KIND path,
    # with kind_cluster_name defaulting to `dev`.
    #
    #   k3s   /etc/rancher/k3s/k3s.yaml
    #   rke2  /etc/rancher/rke2/rke2.yaml
    #   kind  no override — the play's own default is correct, precisely BECAUSE
    #         clusterNameVars sets kind_cluster_name in THIS stage too. Hard-
    #         coding it here would need ansible_user, which this module does not
    #         know.
    #
    # rke2 was added on 2026-08-11 with catalog 0.4.0. Without it an rke2
    # ClusterStack inherits the kind default and the upload looks for
    # /home/sthings/.kube/dev on a host that only has
    # /etc/rancher/rke2/rke2.yaml — verified on the reference-run VM. That is
    # the same shape of bug as crossplane-configurations#232: a distribution-
    # specific fact the consumer has to supply, invisible to `crossplane render`.
    _serverPaths = {
        k3s = "/etc/rancher/k3s/k3s.yaml"
        rke2 = "/etc/rancher/rke2/rke2.yaml"
    }
    _dist = spec?.distribution or "k3s"
    _paths = ["kubeconfig_path+-" + _serverPaths[_dist]] if _dist in _serverPaths else []

    # extraVars belongs here too. It was wired into the base-OS and
    # distribution stages only, so an override aimed at THIS stage —
    # secret_path_kubeconfig is the obvious one — vanished without a word:
    # the XRD documents the field, nothing rejects the value, and the
    # rendered varsFile simply does not contain it.
    _vars = renderVars(_stage.vars) + clusterNameVars(_dist, _cluster) + _paths + (stageAnsible(spec, "kubeconfig")?.extraVars or [])

    # STATED EXPLICITLY, even though `vault` is also ansible-run's own default.
    # Which Vault the upload authenticates against is a decision this module
    # makes, not one it inherits: if ansible-run's default ever moves, an
    # unset field here would follow it silently and the upload would write
    # kubeconfigs into whatever Vault that is.
    #
    # `vault` is CORRECT and `vault-kubeconfigs` WAS WRONG, which is the reverse
    # of what this comment said until 0.4.1. The old claim — "vault points at the
    # infra Vault and carries no AppRole" — described kind1 in July 2026 and has
    # not been true since: secrets/vault.enc.yaml carries VAULT_ADDR
    # https://vault-vsphere.labul.sva.de:8200 plus the AppRole that owns the
    # kubeconfigs mount (policy `superuser`), and the infra credential moved to
    # its own blob, `vault-infra`. The two names cannot collide any more.
    #
    # Nothing ever created a Secret called `vault-kubeconfigs`. The fleet's
    # sops-git-secrets chart derives a Secret's name from metadata.name inside
    # its encrypted blob, so the name could only have come from a fourth blob
    # duplicating a credential that is already on every cluster — a second copy
    # to rotate, and a silent breakage the day someone rotates only one. Verified
    # on u26-kind3 (2026-08-12): VAULT_ADDR, VAULT_ROLE_ID and VAULT_SECRET_ID of
    # a hand-made `vault-kubeconfigs` sha256-matched `vault` exactly.
    #
    # So an rke2/k3s upload on a fresh machinery cluster failed with "failed to
    # determine alias name from login request" — the same symptom the old comment
    # blamed on leaving the field unset — until someone hand-created the alias.
    #
    # NOT the same name as ClusterAccess's kubeconfigProviderConfigRef below,
    # which stays `vault-kubeconfigs`: that is a ClusterProviderConfig created by
    # the provider-kubeconfig-vault chart, not a Secret.
    _vaultSecret = (spec?.kubeconfig or {})?.vaultSecretName or "vault"
    _ansibleRun(name, ns, "kubeconfig", spec, _stage.playbooks, _vars, renderInventory(_stage.inventoryGroups, ip), _vaultSecret, "")
}

# --- the rancher path ------------------------------------------------------
# One stage instead of two. On the ansible path the distribution run installs
# Kubernetes and a second run uploads the kubeconfig; here Rancher installs it
# (the node runs the registration command Rancher published) and the SAME play
# uploads the kubeconfig, because both need this node at this moment.
joinRun = lambda name: str, ns: str, spec: {str:any}, ip: str, nodeCommandSecret: str -> {str:any} {
    _cluster = spec?.clusterName or name
    _dist = cat.getDistribution(spec?.distribution or "k3s")
    _kc = spec?.kubeconfig or {}

    # The same credential the ansible path uses for its upload stage — the play
    # writes to kubeconfigs/<cluster> with it.
    _vaultSecret = _kc?.vaultSecretName or "vault"
    _vars = renderVars(_dist.vars) + clusterNameVars(spec?.distribution or "k3s", _cluster) + (stageAnsible(spec, "join")?.extraVars or [])
    _ansibleRun(name, ns, "join", spec, _dist.playbooks, _vars, renderInventory(_dist.inventoryGroups, ip), _vaultSecret, nodeCommandSecret)
}

# The RancherCluster child: Rancher creates the cluster, and its
# nodeRegistration Secret is what the VM's join stage waits for.
#
# publish is forced on and secretNamespace defaults to the ansible pipeline
# namespace, because ansible-run reads extraEnvSecretName from the PipelineRun's
# namespace — not from next to this XR. A registration command published only
# beside the XR is a command the join cannot read.
rancherChild = lambda name: str, ns: str, spec: {str:any}, appArgocd: {str:any} = {} -> {str:any} {
    _cluster = spec?.clusterName or name
    _dist = cat.getDistribution(spec?.distribution or "k3s")
    _r = spec?.rancher or {}
    _ans = stageAnsible(spec, "join")
    _passthrough = {k: v for k, v in _r if k not in ["name", "machineGlobalConfig", "nodeRegistration"]}

    # Catalog first, XR on top: a caller can override one key without
    # restating the set that keeps rke2 out of the network.
    _mgc = _dist.machineGlobalConfig | (_r?.machineGlobalConfig or {})
    _nodeReg = (_r?.nodeRegistration or {}) | {
        publish = True
        secretNamespace = (_r?.nodeRegistration or {})?.secretNamespace or _ans?.pipelineNamespace or "tekton-ci"
    }
    {
        apiVersion = "resources.stuttgart-things.com/v1alpha1"
        kind = "RancherCluster"
        metadata = {
            name = "{}-rancher".format(name)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "rancher"}
        }
        spec = _passthrough | {
            name = _cluster
            machineGlobalConfig = _mgc
            nodeRegistration = _nodeReg
            # Only when there is something to register or derive — an empty
            # argocd block would be a diff on every existing RancherCluster.
            if (_r?.argocd or spec?.profiles or spec?.secretStores):
                argocd = argocdBlock(spec, appArgocd)
        }
    }
}

# --- Argo CD labels and annotations: profiles, derived facts, overrides -----
# rancher-join-test5 carried ~35 hand-written labels and annotations and needed
# five edits after it was ordered. Two different things were mixed in that list:
#
#   CHOICES — which app platforms this cluster runs. Named profiles from the
#   catalog (decision 6.2), so a choice is one word instead of a label set.
#
#   FACTS — values this stack already knows because it composes them: the Vault
#   address, the issuer name, which KV mounts the eso role opens, whether the
#   cluster seeds its own observability entry. Written by hand they drift, and
#   the opt-in gates among them (…/secrets-config,
#   security-platform/external-secrets-stores) assert that a Vault role can read
#   a mount — only the stack that composes the role can state that honestly.
#
# Precedence: profile < derived < spec.rancher.argocd.{labels,annotations}. A
# hand-written value always wins, so nothing a cluster needs is ever blocked.
ESO_AUTH_NAME = "eso"
SHARED_WEBHOOK_ENTRY = "_omni-pitcher"

# Later profile wins on a shared key. Two KCL traps shaped this:
#   - a dict comprehension with a repeated key is an EvaluationError, not an
#     overwrite, so `{k: v for p in profiles for k, v in ...}` fails as soon as
#     two profiles share a key;
#   - the first draft accumulated with `_acc := _acc | ...` inside a list
#     comprehension. KCL returned an empty dict without error, and `kcl fmt`
#     then silently DELETED the `:=` expression from the source. The profile
#     tests caught the first; reading the diff caught the second.
# So: flatten to [key, value] pairs in list order, keep each key once, take its
# last value.
mergeLastWins = lambda pairs: [[str]] -> {str:str} {
    _keys = [x[0] for i, x in pairs if x[0] not in [y[0] for y in pairs[:i:]]]
    {k: [x[1] for x in pairs if x[0] == k][-1] for k in _keys}
}

profileLabels = lambda spec: {str:any} -> {str:str} {
    mergeLastWins([[k, v] for p in (spec?.profiles or []) for k, v in cat.getProfile(p).labels])
}

profileAnnotations = lambda spec: {str:any} -> {str:str} {
    mergeLastWins([[k, v] for p in (spec?.profiles or []) for k, v in cat.getProfile(p).annotations])
}

derivedArgocd = lambda spec: {str:any}, appArgocd: {str:any} = {} -> {str:any} {
    """Labels and annotations that follow from what this stack composes.

    Returns {labels, annotations}. Asserts the combinations that could only be
    wrong: a store list without the Vault issuer that creates its login, or
    without the eso auth whose mount the stores AppSet assumes.

    appArgocd carries the per-platform secret facts derived from the
    AppSecretProfiles (appSecretArgocd); like the stores they exist only while
    the Platform does.
    """
    _cluster = spec?.clusterName or ""
    _plat = spec?.platform or {}
    _platOn = spec.platformEnabled if "platformEnabled" in spec else True
    _vi = _plat?.vaultIssuer or {}
    _viOn = _platOn and (_vi?.enabled or False)

    # With the Platform off there is no Vault issuer, so there are no stores to
    # derive — and nothing to complain about. `platformEnabled: false` is phase 1
    # of every teardown: asserting here made the whole render fail, Crossplane
    # could no longer remove the Platform, and rancher-join-test6's teardown
    # stopped dead (0.15.2).
    _stores = (spec?.secretStores or []) if _platOn else []
    _cs = _plat?.clusterSecrets or {}
    _csOn = _platOn and (_cs?.enabled or False)
    _obsStore = "observability" in _stores

    assert len(_stores) == 0 or _viOn, "secretStores needs platform.vaultIssuer.enabled — the stores log in through the Vault Kubernetes auth the Platform creates"

    _register = ((spec?.rancher or {})?.argocd or {})?.register or False
    {
        labels = {
            # Every platform ApplicationSet puts its Applications into the
            # project named after the cluster, and cluster-projects creates that
            # AppProject only for `auto-project: "true"`. Without it NOTHING
            # deploys — every AppSet reports "references project … which does
            # not exist". A fact of registering, not a profile choice: it was in
            # test5's hand-written list and got lost when rancher-join-test6
            # switched to profiles.
            if _register:
                "auto-project" = "true"
            if _viOn:
                # The Platform owns the Vault issuer; the AppSet's own would
                # need annotations nothing sets and collide by name.
                "network-platform/cert-manager-vault-pki" = "false"
            if _stores:
                "security-platform/external-secrets-stores" = "true"
            if _csOn and _obsStore:
                "observability-platform.stuttgart-things.com/secrets-config" = "true"
        } | ((appArgocd?.labels or {}) if _platOn else {})
        annotations = {
            if _viOn and _vi?.vaultAddr:
                "clusterbook.stuttgart-things.com/vault-server" = _vi.vaultAddr
            if _viOn:
                "clusterbook.stuttgart-things.com/wildcard-issuer-name" = _vi?.issuerName or "vault-pki-k8s"
            if _stores:
                "external-secrets.stuttgart-things.com/kv-mounts" = ",".join(_stores)
            if _csOn and _obsStore:
                "observability-platform.stuttgart-things.com/secret-store" = "vault-observability"
                # The webhook token is the omni-pitcher's, shared by every
                # cluster — never the cluster's own entry.
                "observability-platform.stuttgart-things.com/alert-webhook-secret-key" = SHARED_WEBHOOK_ENTRY
            if _csOn and _obsStore and _cs?.path and _cs.path != _cluster:
                "observability-platform.stuttgart-things.com/secret-key" = _cs.path
        } | ((appArgocd?.annotations or {}) if _platOn else {})
    }
}

argocdBlock = lambda spec: {str:any}, appArgocd: {str:any} = {} -> {str:any} {
    """spec.rancher.argocd with profiles and derived facts merged under the
    caller's own labels and annotations."""
    _a = (spec?.rancher or {})?.argocd or {}
    _d = derivedArgocd(spec, appArgocd)
    _a | {
        labels = profileLabels(spec) | _d.labels | (_a?.labels or {})
        annotations = profileAnnotations(spec) | _d.annotations | (_a?.annotations or {})
    }
}

# --- who owns kubeconfigs/<cluster> ----------------------------------------
# The upload writes that entry; until now nothing removed it, so a torn-down
# cluster left its kubeconfig in Vault — rancher-join-test3 and -test4 both did.
#
# This Workspace claims the entry by writing custom_metadata and, on destroy,
# DELETEs <mount>/metadata/<cluster>, which removes every version. It never
# touches the secret data: the join play writes that.
#
# The credential is the WRITER approle in terraform.tfvars form. Its policy
# needs create/update on kubeconfigs/metadata/* — added and verified on the
# infra Vault 2026-09-16 (stuttgart-things/stuttgart-things#2990); before that
# the same call was a 403.
_KUBECONFIG_LIFECYCLE_HCL = """terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25"
    }
  }
}

variable "vault_addr" {
  type = string
}

variable "metadata_path" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vault_role_id" {
  type = string
}

variable "vault_secret_id" {
  type      = string
  sensitive = true
}

provider "vault" {
  address          = var.vault_addr
  skip_tls_verify  = true
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# Owns the ENTRY, never its content: the join play writes the kubeconfig into
# <mount>/data/<cluster> and keeps writing new versions. Writing custom_metadata
# is what marks the entry as Crossplane-owned; destroying this resource DELETEs
# the metadata path, and with it every version.
#
# disable_read: a GET on the metadata path returns a different shape than the
# POST takes, so reading it back would diff forever.
resource "vault_generic_endpoint" "kubeconfig_metadata" {
  path                 = var.metadata_path
  disable_read         = true
  ignore_absent_fields = true

  data_json = jsonencode({
    custom_metadata = {
      "managed-by" = "crossplane"
      "cluster"    = var.cluster_name
    }
  })
}
"""

kubeconfigLifecycle = lambda spec: {str:any} -> {str:any} {
    (spec?.kubeconfig or {})?.lifecycle or {}
}

kubeconfigLifecycleEnabled = lambda spec: {str:any} -> bool {
    """Default follows the provisioner: on for rancher, off for the ansible path.

    Not because the ansible path does not leak the same entry — it does — but
    because turning it on there changes the teardown of clusters that already
    exist. An explicit `enabled` wins either way.
    """
    _l = kubeconfigLifecycle(spec)
    _l.enabled if "enabled" in _l else (cat.getDistribution(spec?.distribution or "k3s").provisioner == "rancher")
}

kubeconfigWorkspace = lambda name: str, ns: str, spec: {str:any} -> {str:any} {
    """The Workspace that owns the Vault entry for this cluster's kubeconfig.

    Values travel as Workspace VARS, not baked into the HCL: the module stays a
    constant, and a cluster name never lands inside a quoted HCL literal.
    """
    _cluster = spec?.clusterName or name
    _kc = spec?.kubeconfig or {}
    _l = kubeconfigLifecycle(spec)
    _addr = _l?.vaultAddr or ""
    assert _addr, "kubeconfig.lifecycle needs vaultAddr — the Workspace that owns the kubeconfig entry of " + _cluster + " has to know which Vault that is; set kubeconfig.lifecycle.enabled to false to keep the entry instead"
    _mount = _l?.mount or "kubeconfigs"
    _path = _kc?.vaultPath or _cluster
    {
        apiVersion = "opentofu.m.upbound.io/v1beta1"
        kind = "Workspace"
        metadata = {
            name = "{}-kubeconfig-vault".format(name)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "kubeconfig-vault"}
        }
        spec = {
            providerConfigRef = {
                name = _l?.providerConfigName or "in-cluster"
                kind = "ClusterProviderConfig"
            }
            forProvider = {
                source = "Inline"
                module = _KUBECONFIG_LIFECYCLE_HCL
                vars = [
                    {key = "vault_addr", value = _addr}
                    {key = "metadata_path", value = "{}/metadata/{}".format(_mount, _path)}
                    {key = "cluster_name", value = _cluster}
                ]
                varFiles = [{
                    source = "SecretKey"
                    format = "HCL"
                    secretKeyRef = {
                        name = _l?.credentialSecret or "vault-kubeconfig-writer"
                        key = "terraform.tfvars"
                    }
                }]
            }
        }
    }
}

# vaultSecretName says WHERE THE UPLOAD WRITES, providerConfigRef says WHERE THE
# READ COMES FROM. They must mean the same Vault, and until 0.9.0 nothing enforced
# that: the defaults `vault` and `vault-kubeconfigs` agreed by accident, but the
# moment someone set vaultSecretName to vault-infra -- which the ArgoCD path
# requires, because the ClusterSecretStore reads the infra Vault -- the pair came
# apart and the RemoteCluster looked for the kubeconfig in the other Vault:
#
#   cannot read kubeconfig from Vault: secret not found: at kubeconfigs/data/<c>
#
# Nothing above it reports an error. The ClusterStack stays Ready=True, because
# without a ready ClusterAccess the Platform branch is not emitted at all and
# there is nothing left to wait for. Measured on argoplatform-test2, 2026-08-19:
# 40 minutes to find. See crossplane-configurations#336.
#
# So the read side is DERIVED from the upload side by default. An explicit
# providerConfigRef still wins -- it is the escape hatch for a Vault pair this
# map does not know -- but it is no longer required to state the obvious.
kubeconfigVaultPairs: {str:str} = {
    "vault" = "vault-kubeconfigs"
    "vault-infra" = "vault-kubeconfigs-infra"
    # The rancher join uploads with the WRITER approle; reading the entry back
    # still goes through the infra vault's read config. Without this pair the
    # fallback below would send the RemoteCluster to the wrong Vault, and the
    # only symptom is "secret not found" on a path that exists.
    "vault-infra-kubeconfig-writer" = "vault-kubeconfigs-infra"
    # LabDA, 2026-08-20. Eigener Vault (vault-vsphere.tiab.labda.sva.de), NICHT
    # einer der beiden LabUL-Vaults: LabUL-vSphere wird abgeschaltet, und ein
    # LabDA-Cluster soll seinen kubeconfig nicht dort ablegen. Der Eintrag hier
    # ist das, was den Aufrufer davon befreit, kubeconfig.providerConfigRef von
    # Hand zu setzen -- und genau dieses Handsetzen ist in #336 schiefgegangen.
    "vault-labda" = "vault-kubeconfigs-labda"
}

kubeconfigReadRef = lambda kc: {str:} -> str {
    """The ClusterProviderConfig the ClusterAccess reads the kubeconfig through.

    Explicit wins; otherwise derived from vaultSecretName. An unknown
    vaultSecretName falls back to the historical default rather than failing --
    the XRD rejects the two combinations we know to be wrong, and guessing past
    that would break setups this map has never seen.
    """
    _upload = kc?.vaultSecretName or "vault"
    kc?.providerConfigRef or kubeconfigVaultPairs[_upload] or "vault-kubeconfigs"
}

# --- the two downstream XRs ------------------------------------------------
clusterAccess = lambda name: str, ns: str, spec: {str:any} -> {str:any} {
    _cluster = spec?.clusterName or name
    _kc = spec?.kubeconfig or {}
    {
        apiVersion = "config.stuttgart-things.com/v1alpha1"
        kind = "ClusterAccess"
        metadata = {
            name = "{}-access".format(name)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "access"}
        }
        spec = {
            clusterName = _cluster
            source = {
                type = "vault"
                path = _kc?.vaultPath or _cluster
                key = "kubeconfig"
            }
            secretNamespace = _kc?.secretNamespace or "crossplane-system"
            kubeconfigProviderConfigRef = kubeconfigReadRef(_kc)
        }
    }
}

# The Platform child. clusterName and cni.enabled are supplied HERE, not by the
# user: cni.enabled follows from the distribution's CNI ownership, and setting it
# by hand is how a cluster ends up with two CNIs (a k3s role installs cilium
# itself; a kind cluster is deliberately built without one).
# --- Vault token policies: derived, never passed through, in rancher mode -----
# A Kubernetes-auth role in Vault has no allowed_policies: whoever may write
# auth/<mount>/role/* may attach ANY existing policy, including ones they do not
# hold. Passing `tokenPolicies` from the order to the Platform therefore let
# whoever orders a ClusterStack bind, say, a kubeconfigs reader to a
# ServiceAccount on a cluster they control — cluster-admin on every cluster in
# the fleet (crossplane-configurations#454, addendum to point 5).
#
# In rancher mode the order names STORES, never policies:
#   - the cert-manager auth gets the environment's PKI policies;
#   - the eso auth is derived as a whole from spec.secretStores — its shape is a
#     convention the stores ApplicationSet hard-codes (<cluster>-eso, role eso,
#     external-secrets/eso) — with the policies the environment maps each store
#     to;
#   - a hand-written tokenPolicies, or a hand-written eso entry, fails the
#     render instead of being silently dropped.
#
# The mapping is an ENVIRONMENT value, not a catalog fact: policy names differ per
# Vault (LabUL read-observability-clusters, LabDA read-cicd). It comes from the
# EnvironmentConfig labelled cluster.stuttgart-things.com/environment=<spec.environmentConfig>,
# under `vault`. EnvironmentConfigs are cluster-scoped — only an admin changes it.
#
# The ansible path is untouched: seed-labda-1 passes tokenPolicies today, and
# closing it there is a migration of its own.
ESO_SERVICE_ACCOUNT = "eso"
ESO_NAMESPACE = "external-secrets"

isRancherProvisioner = lambda spec: {str:any} -> bool {
    cat.getDistribution(spec?.distribution or "k3s").provisioner == "rancher"
}

rancherVaultIssuer = lambda spec: {str:any}, env: {str:any} -> {str:any} {
    """The vaultIssuer a rancher-mode Platform gets: tokenPolicies derived from the
    environment and spec.secretStores, never taken from the order."""
    _vi = (spec?.platform or {})?.vaultIssuer or {}
    _ve = env?.vault or {}
    _envName = spec?.environmentConfig or "(unset)"
    _auths = _vi?.additionalAuths or []
    _handTp = [a?.name or "?" for a in _auths if "tokenPolicies" in a]
    _handEso = [a for a in _auths if a?.name == ESO_AUTH_NAME]
    _stores = spec?.secretStores or []
    _storeMap = _ve?.secretStores or {}
    _unknown = [st for st in _stores if st not in _storeMap]
    _cmPolicies = _ve?.certManagerPolicies or []

    assert "tokenPolicies" not in _vi, "platform.vaultIssuer.tokenPolicies is derived in rancher mode — remove it; the cert-manager auth gets vault.certManagerPolicies from the EnvironmentConfig for environment '" + _envName + "'"
    assert len(_handTp) == 0, "tokenPolicies on platform.vaultIssuer.additionalAuths (" + ", ".join(_handTp) + ") are not accepted in rancher mode — a Vault role may be given any existing policy, so the order must not choose them"
    assert len(_handEso) == 0, "the '" + ESO_AUTH_NAME + "' auth is derived from spec.secretStores in rancher mode — remove it from platform.vaultIssuer.additionalAuths"
    assert not (_vi?.enabled or False) or len(_cmPolicies) > 0, "no vault.certManagerPolicies in the EnvironmentConfig for environment '" + _envName + "' (label cluster.stuttgart-things.com/environment) — the cert-manager auth would get a role without policies"
    assert len(_unknown) == 0, "secretStores " + ", ".join(_unknown) + " have no policy in the EnvironmentConfig for environment '" + _envName + "' (vault.secretStores) — a store whose role cannot read reports Valid while every ExternalSecret fails with a 400"

    _flat = [p for st in _stores for p in _storeMap[st]]
    _esoPolicies = [p for i, p in _flat if p not in _flat[:i:]]
    _rest = {k: v for k, v in _vi if k not in ["tokenPolicies", "additionalAuths"]}
    _rest | {
        if _vi?.enabled or False:
            tokenPolicies = _cmPolicies
        additionalAuths = _auths + ([{
            name = ESO_AUTH_NAME
            boundServiceAccountNames = [ESO_SERVICE_ACCOUNT]
            boundServiceAccountNamespaces = [ESO_NAMESPACE]
            createServiceAccounts = True
            tokenPolicies = _esoPolicies
        }] if _stores else [])
    } if _vi else {}
}

# --- app secrets: AppSecretProfiles -> VaultSecretSets, stores, gates (#464) --
# A profile in the catalog names the AppSecretProfiles its workloads read
# (`appSecrets`). The stack fetches exactly those — cluster-scoped, so only an
# admin or the app's owner writes one — and derives from them:
#
#   - one VaultSecretSet per app that OWNS entries: <mount>/<cluster><suffix>
#     with the generate / literal keys, or an override (secretKeyRef, vaultRef)
#     where the order adopts an existing value. Deleted with every version when
#     the stack goes. `shared` and `from` keys are never written: their
#     consumers read the shared `_` entry or the owning app's entry directly;
#   - the stores: every real mount a consumer reads, added to spec.secretStores,
#     so the eso policies and the kv-mounts annotation follow;
#   - per app platform the `…/secret-store` annotation and `…/secrets-config`
#     gate — only where ONE store serves everything the platform reads, since
#     the ApplicationSets take a single store name.
#
# Every Vault fact comes from the environment (`vault.mounts`, `vault.shared`,
# `vault.writer`, `vault.reservedEntries`), never from the order or a profile.
# And every inconsistency is a render error: a missing profile, an unmapped
# mount, a `from` naming an app the order does not have. Failing the render is
# also what keeps a transient gap from deleting live secrets — a failed function
# changes nothing, whereas a VaultSecretSet that is simply not emitted gets
# deleted, generated passwords and all.
APP_SECRET_PROFILE_API_VERSION = "secrets.stuttgart-things.com/v1alpha1"
APP_SECRET_PROFILE_KIND = "AppSecretProfile"
VAULT_SECRET_SET_API_VERSION = "vault.stuttgart-things.com/v1alpha1"

dedup = lambda xs: [str] -> [str] {
    [x for i, x in xs if x not in xs[:i:]]
}

appSecretRequirementName = lambda app: str -> str {
    "app-secret-profile-" + app
}

appSecretNames = lambda spec: {str:any} -> [str] {
    """The AppSecretProfile names the order's profiles need, in profile order.
    Rancher mode only, like the rest of the derived Vault wiring."""
    dedup([n for p in (spec?.profiles or []) for n in cat.getProfile(p).appSecrets]) if isRancherProvisioner(spec) else []
}

appSecretRequirements = lambda names: [str] -> {str:any} {
    """function-kcl's ExtraResources item: fetch each profile by name."""
    {
        apiVersion = "meta.krm.kcl.dev/v1alpha1"
        kind = "ExtraResources"
        requirements = {appSecretRequirementName(n): {
            apiVersion = APP_SECRET_PROFILE_API_VERSION
            kind = APP_SECRET_PROFILE_KIND
            matchName = n
        } for n in names}
    }
}

appSecretsResolved = lambda names: [str], extra: {str:any} -> bool {
    """True once Crossplane answered every requirement — found or not. Before
    that (the first function call of a reconcile) nothing may be derived: that
    response is discarded anyway, and asserting on it would fail every render."""
    all n in names {
        appSecretRequirementName(n) in (extra or {})
    }
}

appSecretProfiles = lambda names: [str], extra: {str:any} -> {str:any} {
    """name -> AppSecretProfile spec, for the profiles that exist."""
    {n: ((extra or {})[appSecretRequirementName(n)][0]?.Resource?.spec or {}) for n in names if (extra or {})[appSecretRequirementName(n)]}
}

# Unset `overridable` follows the source: a generated value may be replaced by
# an existing one, a literal is a fact of the app, a shared key is never written.
keyOverridable = lambda k: {str:any} -> bool {
    k.overridable if "overridable" in k else ("generate" in k)
}

keySource = lambda k: {str:any} -> str {
    "generate" if "generate" in k else ("literal" if "literal" in k else "shared")
}

overrideId = lambda app: str, suffix: str, key: str -> str {
    app + "|" + suffix + "|" + key
}

appSecretPlan = lambda cluster: str, spec: {str:any}, env: {str:any}, names: [str], profiles: {str:any} -> {str:any} {
    """Validate the fetched profiles against the order and the environment and
    return {sets, stores, platforms}:

    sets      — [{app, mount, secrets}] for the VaultSecretSets, apps with
                nothing to write left out;
    stores    — real mounts consumers read, in profile order;
    platforms — umbrella label -> {stores} per catalog profile with appSecrets.
    """
    _ve = env?.vault or {}
    _envName = spec?.environmentConfig or "(unset)"
    _where = " in the EnvironmentConfig for environment '" + _envName + "'"
    _mounts = _ve?.mounts or {}
    _shared = _ve?.shared or {}
    _reserved = _ve?.reservedEntries or {}
    _writer = (_ve?.writer or {})?.providerConfigName or ""
    _missing = [n for n in names if n not in profiles]
    assert len(_missing) == 0, "AppSecretProfile " + ", ".join(_missing) + " not found — listed by the catalog profiles " + ", ".join(spec?.profiles or []) + "; apply the declaration (crossplane-configurations vault/app-secret-profile/examples/profiles) before ordering"

    # Logical -> real mount of every app that owns entries.
    _unmapped = [n for n in names if profiles[n]?.entries and profiles[n]?.mount not in _mounts]
    assert len(_unmapped) == 0, "no vault.mounts entry for the mount of " + ", ".join(_unmapped) + _where
    _realMount = {n: _mounts[profiles[n].mount] for n in names if profiles[n]?.entries}

    _sharedNames = dedup([k.shared for n in names for e in (profiles[n]?.entries or []) for _kn, k in e.keys if "shared" in k])
    _unknownShared = [s for s in _sharedNames if s not in _shared]
    assert len(_unknownShared) == 0, "shared " + ", ".join(_unknownShared) + " has no vault.shared entry" + _where

    # `from` must name an app of this order, an entry it owns and a key in it.
    _reads = [[n, rk, r.from] for n in names for rk, r in (profiles[n]?.reads or {})]
    _badApp = [x[0] + "." + x[1] + " -> " + x[2].app for x in _reads if x[2].app not in names]
    assert len(_badApp) == 0, "reads from an app this order does not have: " + ", ".join(_badApp) + " — add a profile whose appSecrets contain it"
    _entryOf = lambda app: str, suffix: str -> {str:any} {
        _es = [e for e in (profiles[app]?.entries or []) if (e?.suffix or "") == suffix]
        _es[0] if _es else {}
    }
    _badKey = [x[0] + "." + x[1] + " -> " + x[2].app + (x[2]?.suffix or "") + "/" + x[2].key for x in _reads if x[2].key not in (_entryOf(x[2].app, x[2]?.suffix or "")?.keys or {})]
    assert len(_badKey) == 0, "reads a key its source does not declare: " + ", ".join(_badKey)

    # Overrides: only keys the declaration allows, one source each.
    _ovs = spec?.secretOverrides or []
    _badOv = [(o?.app or "?") + (o?.suffix or "") + "/" + (o?.key or "?") for o in _ovs if (o?.app or "") not in names or (o?.key or "") not in (_entryOf(o.app, o?.suffix or "")?.keys or {}) or not keyOverridable(_entryOf(o.app, o?.suffix or "").keys[o.key])]
    assert len(_badOv) == 0, "secretOverrides for keys that do not exist or are not overridable: " + ", ".join(_badOv)
    _badSrc = [o.app + (o?.suffix or "") + "/" + o.key for o in _ovs if ("vaultRef" in o) == ("secretKeyRef" in o)]
    assert len(_badSrc) == 0, "secretOverrides need exactly one of vaultRef or secretKeyRef: " + ", ".join(_badSrc)
    _ovIds = [overrideId(o.app, o?.suffix or "", o.key) for o in _ovs]
    _dupOv = [i for j, i in _ovIds if i in _ovIds[:j:]]
    assert len(_dupOv) == 0, "secretOverrides names a key twice: " + ", ".join(_dupOv)
    _ovById = {overrideId(o.app, o?.suffix or "", o.key): o for o in _ovs}

    _dataItem = lambda app: str, suffix: str, kn: str, k: {str:any} -> {str:any} {
        _id = overrideId(app, suffix, kn)
        _o = _ovById[_id] if _id in _ovById else {}
        _gen = k?.generate or {}
        {
            key = kn
            if "secretKeyRef" in _o:
                secretKeyRef = {name = _o.secretKeyRef.name, key = _o.secretKeyRef.key}
            elif "vaultRef" in _o:
                vaultRef = _o.vaultRef
            elif "generate" in k:
                generate = {length = _gen?.length or 32, charset = _gen?.charset or "alphanumeric"}
            else:
                value = k.literal
        }
    }
    _sets = [{
        app = n
        mount = _realMount[n]
        secrets = [{
            path = cluster + (e?.suffix or "")
            deleteAllVersions = True
            data = [_dataItem(n, e?.suffix or "", kn, e.keys[kn]) for kn in sorted(e.keys) if keySource(e.keys[kn]) != "shared"]
        } for e in profiles[n].entries if any _kn, k in e.keys {
            keySource(k) != "shared"
        }]
    } for n in names if profiles[n]?.entries]
    _written = [s for s in _sets if s.secrets]
    assert len(_written) == 0 or _writer, "no vault.writer.providerConfigName" + _where + " — the VaultSecretSets for " + ", ".join([s.app for s in _written]) + " need the provider-vault ClusterProviderConfig of the cluster-secrets writer"

    # A cluster named like another cluster's suffixed entry would share it:
    # cluster `a-scoreboard` owns schmetterpause/a-scoreboard, which is cluster
    # `a`'s scoreboard entry. And entries still used by hand-seeded fleets are
    # reserved per environment until they migrate.
    _suffixes = dedup([e.suffix for n in names for e in (profiles[n]?.entries or []) if e?.suffix])
    _clash = [sf for sf in _suffixes if cluster.endswith(sf)]
    assert len(_clash) == 0, "cluster name '" + cluster + "' ends with the entry suffix " + ", ".join(_clash) + " — its own entry would be another cluster's"
    _taken = [s.mount + "/" + x.path for s in _written for x in s.secrets if x.path in (_reserved[s.mount] or [])]
    assert len(_taken) == 0, "entries " + ", ".join(_taken) + " are reserved" + _where + " (vault.reservedEntries) — a cluster by this name would overwrite a live entry; pick another clusterName"

    # What each app's consumers read: its own mount when it writes, the shared
    # entry's mount per shared key, the source app's mount (or its shared) per
    # read.
    _keyMount = lambda app: str, suffix: str, kn: str -> str {
        _k = _entryOf(app, suffix).keys[kn]
        _shared[_k.shared].mount if "shared" in _k else _realMount[app]
    }
    _readsOf = lambda n: str -> [str] {
        dedup(([_realMount[n]] if [s for s in _written if s.app == n] else []) + [_shared[k.shared].mount for e in (profiles[n]?.entries or []) for _kn, k in e.keys if "shared" in k] + [_keyMount(r.from.app, r.from?.suffix or "", r.from.key) for _rk, r in (profiles[n]?.reads or {})])
    }
    _platforms = {[k for k, v in cat.getProfile(p).labels if k.endswith("-platform") and "/" not in k and v == "true"][0]: {stores = dedup([m for a in cat.getProfile(p).appSecrets for m in _readsOf(a)])} for p in (spec?.profiles or []) if cat.getProfile(p).appSecrets}
    {
        sets = [s | {providerConfigName = _writer} for s in _written]
        stores = dedup([m for n in names for m in _readsOf(n)])
        platforms = _platforms
    }
}

EMPTY_APP_SECRET_PLAN = {sets = [], stores = [], platforms = {}}

appSecretArgocd = lambda plan: {str:any} -> {str:any} {
    """The per-platform secret facts: a store name and the gate. Only where ONE
    store serves the whole platform — the ApplicationSets take a single store
    name, so a platform reading two mounts gets neither, and stays visibly
    unconfigured instead of half-wired (#464 step 6)."""
    _single = {u: p.stores[0] for u, p in plan.platforms if len(p.stores) == 1}
    {
        labels = {u + ".stuttgart-things.com/secrets-config": "true" for u in _single}
        annotations = {u + ".stuttgart-things.com/secret-store": "vault-" + m for u, m in _single}
    }
}

vaultSecretSetChild = lambda name: str, ns: str, set: {str:any} -> {str:any} {
    {
        apiVersion = VAULT_SECRET_SET_API_VERSION
        kind = "VaultSecretSet"
        metadata = {
            name = "{}-secrets-{}".format(name, set.app)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "app-secrets-" + set.app}
        }
        spec = {
            providerConfigRef = {name = set.providerConfigName, kind = "ClusterProviderConfig"}
            # The mount exists (seeded by Terraform); a VaultSecretSet that
            # created it would orphan it on delete by design, and creating a
            # mount on a path in use fails.
            mount = {path = set.mount, create = False}
            secrets = set.secrets
        }
    }
}

platformChild = lambda name: str, ns: str, spec: {str:any}, apiEndpoint: str, env: {str:any} = {} -> {str:any} {
    _cluster = spec?.clusterName or name
    # `enabled` is no longer filtered here — it lives on spec.platformEnabled.
    _passthrough = {k: v for k, v in (spec?.platform or {}) if k not in ["clusterName", "cni", "vaultIssuer"]}
    _userCni = (spec?.platform or {})?.cni or {}
    _cniEnabled = cat.platformCniEnabled(spec?.distribution or "k3s")

    # Cluster-shape facts from the catalog (API server address, gateway API,
    # l2/externalIPs, hubble) UNDER the caller's own cni block, so one key can
    # be overridden without restating the set. Empty for distributions that
    # install their own CNI.
    _cniDefaults = cat.getDistribution(spec?.distribution or "k3s").cniDefaults

    # vaultIssuer.kubernetesHost is the API server address Vault's Kubernetes
    # auth mount is configured with. Every Platform in the fleet states it by
    # hand today (`https://10.31.102.108:6443`), which is a copied node IP: it
    # goes stale the moment the machine is rebuilt, and nothing notices until an
    # issuer stops working.
    #
    # ClusterAccess DISCOVERS it from the running cluster, so derive it — but
    # only when the user did not set it, because an explicit value may
    # deliberately differ (a VIP or a load balancer in front of the API).
    #
    # NOTE this does not make the endpoint highly available: it is still one
    # node's address. It removes the hand-copied-value failure, not the SPOF.
    # See crossplane-configurations#171.
    _userVault = rancherVaultIssuer(spec, env) if isRancherProvisioner(spec) else ((spec?.platform or {})?.vaultIssuer or {})
    _wantVault = _userVault?.enabled or False
    _hasHost = (_userVault?.kubernetesHost or "") != ""
    _deriveHost = _wantVault and not _hasHost and apiEndpoint != ""
    _vaultDerived = {k: v for k, v in _userVault if k != "kubernetesHost"} | {kubernetesHost = apiEndpoint}
    _vaultPassthrough = {vaultIssuer = _userVault} if _userVault else {}
    _vaultBlock = {vaultIssuer = _vaultDerived} if _deriveHost else _vaultPassthrough

    {
        apiVersion = "config.stuttgart-things.com/v1alpha1"
        kind = "Platform"
        metadata = {
            name = "{}-platform".format(name)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "platform"}
        }
        spec = _passthrough | _vaultBlock | {
            clusterName = _cluster
            cni = _cniDefaults | _userCni | {enabled = _cniEnabled}
        }
    }
}

# A ManagementPlane child, for a cluster that is meant to BUILD clusters rather
# than run workloads. Same passthrough shape as platformChild: whatever the user
# puts under spec.managementPlane reaches the child verbatim, and this
# Composition supplies only clusterName — which it knows and the user should not
# have to repeat.
#
# NOT filtered for `enabled`: that lives on spec.managementPlaneEnabled, a
# sibling, for the same reason platformEnabled is one. A preserve-unknown-fields
# block that also declares known properties makes schema converters emit
# additionalProperties:false and reject every passthrough key.
managementPlaneChild = lambda name: str, ns: str, spec: {str:any} -> {str:any} {
    _cluster = spec?.clusterName or name
    _passthrough = {k: v for k, v in (spec?.managementPlane or {}) if k != "clusterName"}
    {
        apiVersion = "config.stuttgart-things.com/v1alpha1"
        kind = "ManagementPlane"
        metadata = {
            name = "{}-management-plane".format(name)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "management-plane"}
        }
        spec = _passthrough | {
            clusterName = _cluster
        }
    }
}

# --- teardown ordering -----------------------------------------------------

# The one place a composed kind is mapped to its API group. BOTH sides of a
# Usage read it, which is the point: the group used to be an allowlist on `of`
# ("these three kinds are resources.*, everything else is config.*") and a bare
# hardcode on `by`. Either one is wrong by DEFAULT for a kind nobody remembered
# to add -- and wrong here is silent. The Usage is admitted, goes Ready, and
# points at a group/kind pair that does not exist, so it protects nothing;
# teardown then runs straight through, unordered, with no error to notice.
#
# A missing entry is now a KCL error at render time instead.
groupOf = {
    "NativeProxmoxVM" = "resources.stuttgart-things.com/v1alpha1"
    "NativeVsphereVM" = "resources.stuttgart-things.com/v1alpha1"
    "HarvesterVM" = "resources.stuttgart-things.com/v1alpha1"
    "ClusterStack" = "config.stuttgart-things.com/v1alpha1"
    "ClusterAccess" = "config.stuttgart-things.com/v1alpha1"
    "Platform" = "config.stuttgart-things.com/v1alpha1"
    "ManagementPlane" = "config.stuttgart-things.com/v1alpha1"
    "RancherCluster" = "resources.stuttgart-things.com/v1alpha1"
    "Workspace" = "opentofu.m.upbound.io/v1beta1"
}

# Ties the two maps together, so a fourth provider cannot be half-added: the
# module fails to compile until its kind has a group.
assert all _p, _k in vmKindOf {
    _k in groupOf
}, "every kind in vmKindOf needs a groupOf entry, else its Usage guards nothing"

apiVersionOf = lambda kind: str -> str {
    assert kind in groupOf, "no API group known for kind {} -- add it to groupOf".format(kind)
    groupOf[kind]
}

# `of` is what must die LAST, `by` is the user. replayDeletion re-issues the
# delete on the protected resource once the user is gone — without it a
# `kubectl delete` is swallowed and has to be issued twice.
#
# Usage orders DELETION ONLY, never creation: build order stays the ready gates.
#
# `label` identifies the Usage WITHIN the composition and must stay stable;
# `prefix` (the cluster name) is what makes the emitted OBJECT unique in the
# namespace. They were the same string until 0.7.0, and that was a real defect:
# every ClusterStack in a namespace emitted `access-uses-vm`, `platform-uses-vm`
# and so on under those exact names, so the FIRST one to be created owned them
# and every later one failed to apply with
#
#   Usage.protection.crossplane.io "access-uses-vm" is invalid:
#   metadata.ownerReferences: Invalid value: [... ClusterStack "<the-first-one>"]
#
# — Kubernetes refuses a second controller owner. The later ClusterStack then
# sits at Synced=False forever, while its own status.ready still reports true,
# so it reads as finished. Observed on kind3 with three stacks: the 4-day-old
# one held all four names, a 26-hour-old one had been unsynced that whole time
# unnoticed, and a third could not be built at all.
usage = lambda ofKind: str, ofName: str, byKind: str, byName: str, label: str, replay: bool, prefix: str -> {str:any} {
    {
        apiVersion = "protection.crossplane.io/v1beta1"
        kind = "Usage"
        metadata = {
            name = "{}-{}".format(prefix, label)
            annotations = {"krm.kcl.dev/composition-resource-name" = label}
        }
        spec = {
            replayDeletion = replay
            of = {
                apiVersion = apiVersionOf(ofKind)
                kind = ofKind
                resourceRef.name = ofName
            }
            by = {
                apiVersion = apiVersionOf(byKind)
                kind = byKind
                resourceRef.name = byName
            }
        }
    }
}

platformDomain = lambda plat: {str:} -> str {
    """The cluster's DNS domain, read off an observed Platform child.

    Discovered two levels down: the ipReservation child asks clusterbook, which
    returns a `*.` wildcard when createDNS is set; platform reduces it to the
    usable name and republishes it as components.ipReservation.domain. This only
    lifts it into the stack's own share, for the same reason apiEndpoint is
    lifted — state it once where it is discovered, read it everywhere else.

    Returns "" when ipReservation is off, has no DNS, or the Platform has not
    reported yet. Callers omit the field rather than publishing an empty string:
    a blank domain substituted into a Gateway hostname or a certificate is worse
    than an absent one, because it renders as a valid-looking empty value.
    """
    ((plat?.status?.components or {})?.ipReservation or {})?.domain or ""
}
