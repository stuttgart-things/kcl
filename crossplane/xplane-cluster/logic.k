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

# --- the VM child ----------------------------------------------------------
vmChild = lambda name: str, ns: str, spec: {str:any}, size: any -> {str:any} {
    _provider = spec?.provider or "proxmox"
    _cluster = spec?.clusterName or name
    _vm = spec?.vm or {}
    _ans = spec?.ansible or {}

    # Base-OS stage. vm_hostname is not cosmetic on Proxmox: bpg cloud-init
    # cannot set the guest hostname without a snippets datastore, so
    # sthings.baseos.setup does it from this var.
    _baseVars = [
        "manage_filesystem+-true"
        "update_packages+-true"
        "vm_hostname+-{}".format(_cluster)
    ] + (_ans?.extraVars or [])

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
_ansibleRun = lambda name: str, ns: str, stage: str, spec: {str:any}, playbooks: [str], vars: [str], inventory: [str] -> {str:any} {
    _ans = spec?.ansible or {}
    _runID = spec?.runID or ""
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
    _vars = renderVars(_dist.vars) + ["cluster_name+-{}".format(_cluster)] + (spec?.ansible?.extraVars or [])
    _ansibleRun(name, ns, "distribution", spec, _dist.playbooks, _vars, renderInventory(_dist.inventoryGroups, ip))
}

kubeconfigRun = lambda name: str, ns: str, spec: {str:any}, ip: str -> {str:any} {
    _cluster = spec?.clusterName or name
    _stage = cat.kubeconfigStage
    _dist = cat.getDistribution(spec?.distribution or "k3s")

    # Where the kubeconfig sits on the node differs per distribution; the k3s
    # server writes /etc/rancher/k3s/k3s.yaml, while the kind role fetches to the
    # user's home. Only k3s needs the override.
    _paths = ["kubeconfig_path+-/etc/rancher/k3s/k3s.yaml"] if (spec?.distribution or "k3s") == "k3s" else []
    _vars = renderVars(_stage.vars) + ["cluster_name+-{}".format(_cluster)] + _paths
    _ansibleRun(name, ns, "kubeconfig", spec, _stage.playbooks, _vars, renderInventory(_stage.inventoryGroups, ip))
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
platformChild = lambda name: str, ns: str, spec: {str:any} -> {str:any} {
    _cluster = spec?.clusterName or name
    _passthrough = {k: v for k, v in (spec?.platform or {}) if k not in ["enabled", "clusterName", "cni"]}
    _userCni = (spec?.platform or {})?.cni or {}
    _cniEnabled = cat.platformCniEnabled(spec?.distribution or "k3s")
    {
        apiVersion = "config.stuttgart-things.com/v1alpha1"
        kind = "Platform"
        metadata = {
            name = "{}-platform".format(name)
            namespace = ns
            annotations = {"krm.kcl.dev/composition-resource-name" = "platform"}
        }
        spec = _passthrough | {
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
usage = lambda ofKind: str, ofName: str, byKind: str, byName: str, label: str -> {str:any} {
    {
        apiVersion = "protection.crossplane.io/v1beta1"
        kind = "Usage"
        metadata = {
            name = label
            annotations = {"krm.kcl.dev/composition-resource-name" = label}
        }
        spec = {
            replayDeletion = True
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
