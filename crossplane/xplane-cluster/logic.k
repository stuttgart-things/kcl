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

_ansibleRun = lambda name: str, ns: str, stage: str, spec: {str:any}, playbooks: [str], vars: [str], inventory: [str], vaultSecret: str -> {str:any} {
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
    _ansibleRun(name, ns, "distribution", spec, _dist.playbooks, _vars, renderInventory(_dist.inventoryGroups, ip), "")
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
    _ansibleRun(name, ns, "kubeconfig", spec, _stage.playbooks, _vars, renderInventory(_stage.inventoryGroups, ip), _vaultSecret)
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
platformChild = lambda name: str, ns: str, spec: {str:any}, apiEndpoint: str -> {str:any} {
    _cluster = spec?.clusterName or name
    # `enabled` is no longer filtered here — it lives on spec.platformEnabled.
    _passthrough = {k: v for k, v in (spec?.platform or {}) if k not in ["clusterName", "cni", "vaultIssuer"]}
    _userCni = (spec?.platform or {})?.cni or {}
    _cniEnabled = cat.platformCniEnabled(spec?.distribution or "k3s")

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
    _userVault = (spec?.platform or {})?.vaultIssuer or {}
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
            cni = _userCni | {enabled = _cniEnabled}
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
                # HarvesterVM lives in the same group as the two native VMs.
                # Forgetting it here does not fail loudly -- it emits a Usage
                # pointing at config.stuttgart-things.com/HarvesterVM, a kind
                # that does not exist, and the protection silently guards
                # nothing.
                apiVersion = "resources.stuttgart-things.com/v1alpha1" if ofKind in ["NativeProxmoxVM", "NativeVsphereVM", "HarvesterVM"] else "config.stuttgart-things.com/v1alpha1"
                kind = ofKind
                resourceRef.name = ofName
            }
            by = {
                apiVersion = "config.stuttgart-things.com/v1alpha1"
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
