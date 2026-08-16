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
            # ALL FIVE are required even though the artifact defaults every
            # one of them, and that is the point: each default names a
            # different deployment. Live on u26-rke2-1, 2026-08-16, the store
            # came up as `vault-homerun2-cd`, reading KV path `homerun2-cd`,
            # authenticating as a ServiceAccount `eso` that the chart does not
            # create — and reported no error at all until it tried to reach
            # Vault.
            #
            #   VAULT_K8S_AUTH_MOUNT_PATH  platform-sthings-eso   another cluster
            #   VAULT_K8S_AUTH_ROLE        eso                    another cluster
            #   VAULT_CSS_NAME             vault-homerun2-cd      another workload
            #   VAULT_KV_PATH              homerun2-cd            another mount
            #   VAULT_K8S_AUTH_SA_NAME     eso                    no such SA
            #
            # A store pointed at the wrong Vault LOOKS configured, which is the
            # failure class requiredSubstitutions exists for. Required, each is
            # either discovered from this cluster's own vaultIssuer or rejected
            # at render time by name.
            #
            # VAULT_K8S_AUTH_SA_NAME is the odd one out: the SA name is a fact
            # about the artifact's own chart, not a per-cluster decision, so
            # every XR will type the same value. The real fix is the artifact
            # defaulting to the SA it actually creates (`external-secrets`);
            # drop it from this list once that lands — the same way
            # MACHINERY_VERSION left it after stuttgart-things/flux#193.
            requiredSubstitutions = [
                "VAULT_K8S_AUTH_MOUNT_PATH"
                "VAULT_K8S_AUTH_ROLE"
                "VAULT_CSS_NAME"
                "VAULT_KV_PATH"
                "VAULT_K8S_AUTH_SA_NAME"
            ]
            substitutionSources = {
                VAULT_K8S_AUTH_MOUNT_PATH = "vaultIssuer.auths.eso.mountPath"
                VAULT_K8S_AUTH_ROLE = "vaultIssuer.auths.eso.role"
            }
        }
    ]
}
