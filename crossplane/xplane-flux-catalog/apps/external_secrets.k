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
        # The mount path and role are DISCOVERED from this cluster's own
        # vaultIssuer, which created them. Before xplane-platform 0.14.0 the
        # status published only readiness flags, so the artifact's defaults —
        # mount `platform-sthings-eso`, role `eso` — were the only option, and
        # they describe one specific cluster. A second cluster silently
        # authenticated against the wrong mount, or against nothing.
        #
        # Requires spec.vaultIssuer.additionalAuths to declare an auth named
        # `eso`. Where it does not, the paths resolve to nothing, the variables
        # stay at the artifact's defaults, and the store points wherever those
        # point — which is why this component is opt-in.
        s.Component {
            name = "cluster-store-vault"
            path = "./components/cluster-store-vault"
            optional = True
            dependsOn = ["install"]
            # REQUIRED even though the artifact defaults them, and that is the
            # point: the defaults are `platform-sthings-eso` / `eso`, i.e. one
            # specific cluster's mount. On any other cluster they authenticate
            # against the wrong mount or against nothing, and the store looks
            # configured either way.
            #
            # Declared required, they are either DISCOVERED from this cluster's
            # own vaultIssuer or rejected by name at render time. Never silently
            # someone else's.
            requiredSubstitutions = ["VAULT_K8S_AUTH_MOUNT_PATH", "VAULT_K8S_AUTH_ROLE"]
            substitutionSources = {
                VAULT_K8S_AUTH_MOUNT_PATH = "vaultIssuer.auths.eso.mountPath"
                VAULT_K8S_AUTH_ROLE = "vaultIssuer.auths.eso.role"
            }
        }
    ]
}
