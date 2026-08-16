import ..schema as s

# external-secrets — https://github.com/stuttgart-things/flux/tree/main/infra/external-secrets
#
# The one entry that is also an ANSWER rather than just an app: once a
# ClusterSecretStore stands, a catalog app can reference an ExternalSecret
# instead of carrying a password. Substitutions land in `postBuild.substitute`,
# i.e. in the XR spec and therefore in git in the clear — which is why harbor,
# kube-prometheus-stack and argo-cd are not in this catalog yet. This is what
# unblocks them.
externalSecrets: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/infra/external-secrets"
    defaultVersion = "v1.18.1"
    components = [
        s.Component {
            name = "install"
            path = "./components/install"
            wrapsHelmRelease = True
            timeout = "15m"
        }
        # The Vault-backed ClusterSecretStore. Optional because a cluster may
        # want ESO with a different backend, or none yet.
        #
        # Every variable it needs carries a default, so it renders without an
        # XR saying anything — but the defaults describe THIS fleet's usual
        # Vault (mount `platform-sthings-eso`, role `eso`, CA in cert-manager),
        # and a cluster whose vaultIssuer created a differently named mount has
        # to say so.
        #
        # NO substitutionSources yet, and that is a gap rather than a choice:
        # the values are exactly what `vaultIssuer` creates, but Platform's
        # status.components.vaultIssuer publishes only readiness flags
        # (authReady/caReady/issuerReady) — the Tofu outputs auth_backend_path
        # and auth_role_name reach nothing. Wire them here the moment
        # VaultK8sAuth publishes a status; see
        # crossplane-configurations#260.
        s.Component {
            name = "cluster-store-vault"
            path = "./components/cluster-store-vault"
            optional = True
            dependsOn = ["install"]
        }
    ]
}
