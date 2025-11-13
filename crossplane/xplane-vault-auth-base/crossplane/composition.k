import xplane_vault_auth as vault

# Get XR spec fields
authName = option("params")?.oxr?.spec?.name or "vault-auth"
authNamespace = option("params")?.oxr?.spec?.namespace or "default"
clusterName = option("params")?.oxr?.spec?.clusterName or "default"
clusterRole = option("params")?.oxr?.spec?.clusterRole or "system:auth-delegator"
vaultAddr = option("params")?.oxr?.spec?.vaultAddr or ""
vaultNamespace = option("params")?.oxr?.spec?.vaultNamespace or "default"
authPath = option("params")?.oxr?.spec?.authPath or "kubernetes"
labels = option("params")?.oxr?.spec?.labels or {}
annotations = option("params")?.oxr?.spec?.annotations or {}

# Create Vault Kubernetes authentication
authConfig = vault.K8sAuth {
    name = authName
    namespace = authNamespace
    clusterName = clusterName
    clusterRole = clusterRole
    vaultAddr = vaultAddr
    vaultNamespace = vaultNamespace
    authPath = authPath
    labels = labels
    annotations = annotations
}

# Generate Terraform workspace
workspace = vault.vaultK8sAuth(authConfig)[0]

# Add composition resource name annotation
workspaceWithAnnotations = {
    **workspace
    metadata = {
        **workspace.metadata
        annotations = {
            **workspace.metadata.annotations
            "krm.kcl.dev/composition-resource-name" = "vault-auth-workspace"
        }
    }
}

# Status information
_oxr = {
    **option("params").oxr
    status = {
        serviceAccountName = "{}-vault-auth".format(authName)
        workspaceName = workspace.metadata.name
        ready = True
    }
}

# Outputs
items = [workspaceWithAnnotations]
oxr = _oxr
