import ..schema as s

# sops-secrets-operator — https://github.com/stuttgart-things/flux/tree/main/apps/sops-secrets-operator
#
# Turns a `SopsSecret` — an age-encrypted blob committed to git — into a real
# Kubernetes Secret. The reason a management cluster wants it: the capability
# charts each ship their own SopsSecretManifest, so without the operator those
# credentials stay encrypted blobs and every provider that needs them sits
# without a config.
#
# NOT a HelmRelease: the app pulls a kustomize base built from the operator's
# config/default, so there is no chart to wait on. 10m rather than the 15m the
# Helm-wrapping entries use — CRDs and a Deployment, no chart pull.
#
# NO cert-manager dependency, which is worth stating because the obvious
# assumption is wrong. Upstream (isindir/sops-secrets-operator, group
# isindir.github.com) ships a validating webhook and `config/default` wires in
# ../webhook and ../certmanager. This is NOT that operator: it is
# stuttgart-things/sops-secrets-operator, group sops.stuttgart-things.com, and
# the artifact it publishes contains exactly a Namespace, 5 CRDs, a
# ServiceAccount, a ClusterRole+Binding and a Deployment. Verified against the
# published v0.9.0 artifact and against a live install on u26-rke2-1
# (2026-08-17): no ValidatingWebhookConfiguration, no Certificate, no cert
# volume on the Deployment. Adding the dependency back would not be a harmless
# extra edge — the catalog REJECTS an app whose dependency is not enabled, so
# it would deny this operator to any cluster that does not run cert-manager.
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
        }
    ]
}
