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

    # The ONLY place the two providers differ: field names. Staging, gating and
    # everything downstream are identical (crossplane-configurations#168,
    # option A).
    _res = {
        if _provider == "vsphere":
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
    _vars = renderVars(_stage.vars) + clusterNameVars(_dist, _cluster) + _paths

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
            kubeconfigProviderConfigRef = _kc?.providerConfigRef or "vault-kubeconfigs"
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

# --- teardown ordering -----------------------------------------------------

# `of` is what must die LAST, `by` is the user. replayDeletion re-issues the
# delete on the protected resource once the user is gone — without it a
# `kubectl delete` is swallowed and has to be issued twice.
#
# Usage orders DELETION ONLY, never creation: build order stays the ready gates.
usage = lambda ofKind: str, ofName: str, byKind: str, byName: str, label: str, replay: bool -> {str:any} {
    {
        apiVersion = "protection.crossplane.io/v1beta1"
        kind = "Usage"
        metadata = {
            name = label
            annotations = {"krm.kcl.dev/composition-resource-name" = label}
        }
        spec = {
            replayDeletion = replay
            of = {
                apiVersion = "resources.stuttgart-things.com/v1alpha1" if ofKind in ["NativeProxmoxVM", "NativeVsphereVM"] else "config.stuttgart-things.com/v1alpha1"
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
