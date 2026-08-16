"""
Status shaping for the vault-auth Composition.

Separated from main.k so it can be unit-tested without Crossplane. What is
worth testing here is not the marshalling but the rule: a value that the
Workspace has not produced yet must be OMITTED, never published empty.
"""

# The Workspace the base module builds for one auth. Derived rather than passed,
# because the two must agree and a second source of truth is how they drift.
workspaceName = lambda clusterName: str, authName: str -> str {
    "{}-{}-vault-auth".format(clusterName, authName)
}

isReady = lambda res: any -> bool {
    len([c for c in (res?.status?.conditions or []) if c?.type == "Ready" and c?.status == "True"]) > 0
}

authStatus = lambda clusterName: str, authName: str, ws: any -> {str:} {
    """One entry of status.share.auths.

    mountPath, role and policies are OMITTED while the Workspace is still
    applying, rather than published as empty strings. A consumer resolving a
    substitution source to "" would send a blank mount path to Vault, and Vault
    answers that with a 403 that names nothing — the value looks supplied and is
    not. Absent is a state a consumer can act on; empty is not.
    """
    _out = ((ws?.status?.atProvider or {})?.outputs or {})
    {
        name = authName
        workspace = workspaceName(clusterName, authName)
        ready = isReady(ws)
        if _out?.auth_backend_path:
            mountPath = _out.auth_backend_path
        if _out?.auth_role_name:
            role = _out.auth_role_name
        if _out?.policy_names:
            policies = _out.policy_names
    }
}

allReady = lambda auths: [{str:}] -> bool {
    """False on an empty list: a VaultK8sAuth with no auths has created nothing,
    and reporting it ready would let a consumer proceed against a Vault that
    knows nothing about this cluster."""
    len(auths) > 0 and len([a for a in auths if a.ready]) == len(auths)
}
