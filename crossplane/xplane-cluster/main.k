"""
ClusterStack — one XR for VM -> distribution -> access -> platform.

This file does the wiring: read observed state, decide which stages are open,
call logic.k to build the children, and patch the status.

STICKY GATES. Not emitting a composed resource is what makes Crossplane DELETE
it, so every gate here is `(the previous stage succeeded) OR (this child already
exists)`. Without the second clause a VM blip — bpg and VMware Tools both read
the address from the guest agent, so a momentarily empty value is normal —
would delete an AnsibleRun and its recreation would re-run the play against a
live machine. That failure was real (crossplane-configurations#163); the
AnsibleRun children are re-emitted VERBATIM from _ocds for the same reason: a
rebuilt spec would rewrite the inventory from a now-empty IP, and the wrapped
PipelineRun has no Update policy so it would never reach Tekton anyway.

Gating on SUCCEEDED, not Ready: an AnsibleRun whose PipelineRun failed still
reports Ready once its Object is applied, and unblocking the next stage on that
would run a kubeconfig upload against a cluster that was never installed.
"""

import .logic as l
import xplane_cluster_catalog as cat

_params = option("params") or {}

# Underscore-prefixed so `kcl run` does not echo them as part of the document —
# function-kcl only reads `items`, but a bare top-level name is output too.
# All optional-chained so `kcl test` (which evaluates this file with no params)
# does not blow up before reaching the tests in logic_test.k.
_oxr = _params?.oxr or {}
_ocds = _params?.ocds or {}

_meta = _oxr?.metadata or {}
_name = _meta?.name or "cluster"
_ns = _meta?.namespace or "crossplane-system"
_spec = _oxr?.spec or {}
_cluster = _spec?.clusterName or _name

# Fails loudly with the list of known names rather than silently building a
# default — an unknown size or distribution is a typo, not an intent.
_size = cat.getSize(_spec?.size or "medium")
_dist = cat.getDistribution(_spec?.distribution or "k3s")
_supported = cat.assertSizeSupported(_spec?.distribution or "k3s", _spec?.size or "medium")

# A SIBLING of spec.platform, not a key inside it: `platform` is a verbatim
# passthrough of the Platform XRD's spec, and a preserve-unknown-fields block
# that also declares known properties makes schema converters emit
# additionalProperties:false and reject every passthrough key.
_platformEnabled = _spec?.platformEnabled if "platformEnabled" in _spec else True

# Default OFF, unlike platformEnabled. Most ClusterStacks build WORKLOAD
# clusters; a control plane is the exception, and installing Crossplane plus the
# fleet's twenty packages on a machine that did not ask for it is not a default
# anyone wants to discover.
_mgmtEnabled = _spec?.managementPlaneEnabled if "managementPlaneEnabled" in _spec else False

# --- observed children -----------------------------------------------------
_byKind = lambda kind: str -> [any] {
    [v.Resource for _, v in _ocds if v?.Resource?.kind == kind]
}
_byName = lambda name: str -> [any] {
    [v.Resource for _, v in _ocds if v?.Resource?.metadata?.name == name]
}

_vmKind = "NativeVsphereVM" if (_spec?.provider or "proxmox") == "vsphere" else "NativeProxmoxVM"
_vmObs = _byKind(_vmKind)
_vm = _vmObs[0] if _vmObs else {}
_vmShare = _vm?.status?.share or {}
_vmIPs = _vmShare?.ip or []
_vmIP = _vmIPs[0] if _vmIPs else ""
_vmConds = _vm?.status?.conditions or []
_vmReady = len([c for c in _vmConds if c?.type == "Ready" and c?.status == "True"]) > 0

# Published by proxmoxvm/vspherevm since the sticky-gate release: the base-OS
# PipelineRun's own verdict, not merely the AnsibleRun XR's readiness.
_baseosOk = (_vmShare?.ansibleSucceeded or "") == "True"

_distObs = _byName("{}-distribution".format(_name))
_distRun = _distObs[0] if _distObs else {}
_distOk = (_distRun?.status?.succeeded or "") == "True"

_kcObs = _byName("{}-kubeconfig".format(_name))
_kcRun = _kcObs[0] if _kcObs else {}
_kcOk = (_kcRun?.status?.succeeded or "") == "True"

_accessObs = _byKind("ClusterAccess")
_access = _accessObs[0] if _accessObs else {}
_accessReady = _access?.status?.ready or False
_accessShare = _access?.status?.share or {}

_mgmtObs = _byKind("ManagementPlane")
_mgmt = _mgmtObs[0] if _mgmtObs else {}
_mgmtReady = len([c for c in (_mgmt?.status?.conditions or []) if c?.type == "Ready" and c?.status == "True"]) > 0

_platObs = _byKind("Platform")
_plat = _platObs[0] if _platObs else {}
_platReady = len([c for c in (_plat?.status?.conditions or []) if c?.type == "Ready" and c?.status == "True"]) > 0

# The cluster's DNS domain, discovered by the ipReservation child two levels
# down and republished by platform as components.ipReservation.domain (already
# reduced from clusterbook's `*.` wildcard). Lifted here for the same reason
# apiEndpoint is: state it once where it is discovered, read it everywhere else.
# Empty whenever ipReservation is off or has no DNS — the field is then omitted
# from share rather than published blank.
_platDomain = l.platformDomain(_plat)

# --- gates -----------------------------------------------------------------
_distOpen = (_vmReady and _vmIP != "" and _baseosOk) or len(_distObs) > 0
_kcOpen = (_distOk and _vmIP != "") or len(_kcObs) > 0
_accessOpen = _kcOk or len(_accessObs) > 0
_platOpen = _platformEnabled and (_accessReady or len(_platObs) > 0)

# Gated on ClusterAccess, the same as the Platform child and for the same
# reason: both need only the ClusterProviderConfigs, and neither needs the
# other. They install in parallel — Crossplane and Flux do not contend.
_mgmtOpen = _mgmtEnabled and (_accessReady or len(_mgmtObs) > 0)

# Verbatim re-emission for the ansible children (see the module docstring).
_reemit = lambda prev: any, stage: str -> {str:any} {
    {
        # Defaulted, not read blindly: an observed resource missing apiVersion
        # would otherwise emit a resource without one, which Crossplane accepts
        # into desired state and then cannot apply.
        apiVersion = prev?.apiVersion or "resources.stuttgart-things.com/v1alpha1"
        kind = prev?.kind or "AnsibleRun"
        metadata = {
            name = prev?.metadata?.name or "{}-{}".format(_name, stage)
            namespace = prev?.metadata?.namespace or _ns
            annotations = {"krm.kcl.dev/composition-resource-name" = stage}
        }
        spec = prev?.spec or {}
    }
}

# Verbatim re-emission is a FLAP guard, not a freeze: it applies only while the
# live IP is missing, which is the exact condition that would corrupt a rebuilt
# inventory. With the IP present the spec is rebuilt normally, so a genuine fix
# (a corrected vaultSecretName, a catalog change) can still land — the derived
# names are stable, so nothing re-runs until runID is bumped. Freezing
# unconditionally, as this did first, made a broken stage unfixable without
# deleting the child.
_distChild = _reemit(_distRun, "distribution") if (len(_distObs) > 0 and _vmIP == "") else l.distributionRun(_name, _ns, _spec, _vmIP)
_kcChild = _reemit(_kcRun, "kubeconfig") if (len(_kcObs) > 0 and _vmIP == "") else l.kubeconfigRun(_name, _ns, _spec, _vmIP)

# --- teardown ordering -----------------------------------------------------
# Only the pairs that matter. Usage is not transitive, so a full mesh would be
# noise; these three are the ones whose absence strands a finalizer:
#   - VM must outlive the Platform, else every Platform Object hangs against a
#     dead API server.
#   - ClusterAccess must outlive the Platform, else the ClusterProviderConfigs
#     its Objects reference are gone before they can be finalized.
#   - the VM must outlive ClusterAccess, so the Vault read ends before the
#     machine does.
# The AnsibleRuns need no protection: they only create PipelineRuns on the
# management cluster, and those disappearing blocks nobody.
#
# THOSE THREE CANNOT ORDER THE TEARDOWN OF THEIR OWN PARENT, and that is not a
# bug in them. They are composed children of this XR, so deleting the
# ClusterStack removes them in the SAME parallel sweep as the resources they
# protect, and a Usage whose own object is gone blocks nothing. A live run tore
# the tree down in about three seconds and stranded four resources — a wedged
# flux-instance Object, a flux-operator Release that was never deleted at all,
# and both ClusterProviderConfigs.
#
# The fourth entry below is what fixes that, and it escapes the sweep for one
# reason: it protects the COMPOSITE ITSELF, so the webhook rejects the DELETE at
# ADMISSION — before Crossplane starts deleting anything. Verified on
# u26-rke2-1, 2026-08-12:
#
#   kubectl delete clusterstack u26-rke2-1 --dry-run=server
#   Error: admission webhook "nousages.protection.crossplane.io" denied the
#   request: This resource is in-use by 1 usage(s) ... by resource Platform/...
#
# It does not automate the two-phase teardown; it makes the one-phase teardown
# IMPOSSIBLE instead of silently lossy. `platformEnabled: false` removes both
# the Platform child and this guard, and the delete then goes through.
#
# GATED ON _platOpen, i.e. it exists exactly when the Platform child exists.
# Emitting it unconditionally would make a ClusterStack undeletable, since the
# only thing that clears it is the child going away.
#
# replayDeletion = FALSE here, unlike the three above, and deliberately. Replay
# re-issues a blocked delete once the blocker is gone — convenient when the
# protected thing is a child, dangerous when it is the whole stack: an abandoned
# `kubectl delete` leaves a blocked-delete marker, and a later, unrelated
# `platformEnabled: false` would then tear down the entire cluster by surprise.
#
# COMMAS ARE LOAD-BEARING: without them KCL parses `[a]` followed by a line
# starting with `[` as a SUBSCRIPT, silently dropping entries instead of failing.
_usageGroups = [
    [l.usage(_vmKind, "{}-vm".format(_name), "Platform", "{}-platform".format(_name), "platform-uses-vm", True)] if _platOpen else []
    [l.usage("ClusterAccess", "{}-access".format(_name), "Platform", "{}-platform".format(_name), "platform-uses-access", True)] if (_platOpen and _accessOpen) else []
    [l.usage(_vmKind, "{}-vm".format(_name), "ClusterAccess", "{}-access".format(_name), "access-uses-vm", True)] if _accessOpen else []
    [l.usage("ClusterStack", _name, "Platform", "{}-platform".format(_name), "stack-uses-platform", False)] if _platOpen else []
    # The ManagementPlane needs the same three guards as the Platform, and for
    # the same reasons: it applies everything it owns THROUGH the VM and the
    # ClusterAccess, so losing either first leaves its Objects hanging against a
    # cluster that is gone.
    [l.usage(_vmKind, "{}-vm".format(_name), "ManagementPlane", "{}-management-plane".format(_name), "mgmt-uses-vm", True)] if _mgmtOpen else []
    [l.usage("ClusterAccess", "{}-access".format(_name), "ManagementPlane", "{}-management-plane".format(_name), "mgmt-uses-access", True)] if (_mgmtOpen and _accessOpen) else []
    [l.usage("ClusterStack", _name, "ManagementPlane", "{}-management-plane".format(_name), "stack-uses-mgmt", False)] if _mgmtOpen else []
]
_usages = sum(_usageGroups, [])

# --- status ----------------------------------------------------------------

# The one field to look at when a build is stuck.
# A disabled component is DONE, not pending — otherwise a stack that only wants
# a reachable machine would never report ready.
_platDone = _platReady or (not _platformEnabled and _accessReady)
_mgmtDone = _mgmtReady or not _mgmtEnabled

_stage = "ready" if (_platDone and _mgmtDone) else ("platform" if (_platOpen and not _platDone) else ("management-plane" if _mgmtOpen else ("access" if _accessOpen else ("kubeconfig" if _kcOpen else ("distribution" if _distOpen else ("baseos" if (_vmReady and _vmIP != "") else "vm"))))))

_dxr = _params?.dxr or {}
_dxrPatched = _dxr | {
    status = (_dxr?.status or {}) | {
        ready = _platReady if _platformEnabled else _accessReady
        stage = _stage
        share = {
            clusterName = _cluster
            cniOwnership = _dist.cniOwnership
            if _vmIP:
                ip = _vmIP
            if _accessShare?.apiEndpoint:
                apiEndpoint = _accessShare.apiEndpoint
            if _accessShare?.clusterType:
                clusterType = _accessShare.clusterType
            if _accessShare?.serverVersion:
                serverVersion = _accessShare.serverVersion
            if _platDomain:
                domain = _platDomain
        }
        stages = {
            vm = {ready = _vmReady, ip = _vmIP}
            baseos = {succeeded = _baseosOk}
            distribution = {succeeded = _distOk, emitted = _distOpen}
            kubeconfig = {succeeded = _kcOk, emitted = _kcOpen}
            access = {ready = _accessReady, emitted = _accessOpen}
            platform = {ready = _platReady, emitted = _platOpen}
            managementPlane = {ready = _mgmtReady, emitted = _mgmtOpen}
        }
    }
}

# --- items -----------------------------------------------------------------
# Single-expression concatenation, not `+=` accumulation — the mutable pattern
# double-emitted groups in bootstrap/cilium.
_groups = [
    [l.vmChild(_name, _ns, _spec, _size)]
    [_distChild] if _distOpen else []
    [_kcChild] if _kcOpen else []
    [l.clusterAccess(_name, _ns, _spec)] if _accessOpen else []
    [l.platformChild(_name, _ns, _spec, _accessShare?.apiEndpoint or "")] if _platOpen else []
    [l.managementPlaneChild(_name, _ns, _spec)] if _mgmtOpen else []
    _usages
    [_dxrPatched]
]
items = sum(_groups, [])
