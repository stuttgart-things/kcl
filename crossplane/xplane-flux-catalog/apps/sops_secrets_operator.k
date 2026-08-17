import ..schema as s

# sops-secrets-operator — https://github.com/stuttgart-things/flux/tree/main/apps/sops-secrets-operator
#
# Turns a `SopsSecret` — an age-encrypted blob committed to git — into a real
# Kubernetes Secret. The reason a management cluster wants it: the capability
# charts each ship their own SopsSecretManifest, so without the operator those
# credentials stay encrypted blobs and every provider that needs them sits
# without a config.
#
# Depends on cert-manager for the same reason trust-manager does, but the
# failure is nastier. trust-manager's CRDs simply do not appear; here the
# Deployment comes up healthy and every `SopsSecret` apply is then rejected by a
# validating webhook whose certificate was never issued — which reads like a
# broken CRD rather than a missing dependency.
#
# NOT a HelmRelease: the app pulls a kustomize base built from the operator's
# own config/default, so there is no chart to wait on. 10m rather than the
# 15m the Helm-wrapping entries use — CRDs and a webhook, no chart pull.
#
# The age key is deliberately absent. The operator carries none: it resolves one
# per resource through `spec.decryption.keyRef`, so how a key reaches a cluster
# is a separate decision and not one this entry should make. Today the machinery
# play writes `sops-age-key` into the operator's namespace from SOPS_AGE_KEY; a
# cluster with external-secrets could pull it from Vault instead.
sopsSecretsOperator: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/apps/sops-secrets-operator"
    defaultVersion = "v1.21.0"
    components = [
        s.Component {
            name = "install"
            path = "./"
            timeout = "10m"
            dependsOn = ["cert-manager:install"]
        }
    ]
}
