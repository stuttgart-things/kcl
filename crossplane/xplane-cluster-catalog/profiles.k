# Named label sets for Argo CD app platforms (decision 6.2, #438).
#
# Every entry is checked against what the ApplicationSets in
# stuttgart-things/argocd platforms/ actually select on — see the note on each.
import schema as s

profileTable: {str:s.Profile} = {
    # platforms/network. Opt-out, so the umbrella turns on cilium-lb,
    # cilium-gateway, cert-manager install/selfsigned/cluster-ca and
    # trust-manager install/bundle. Two components are switched OFF because on a
    # cluster built as a ClusterStack they cannot render:
    #   - cert-manager-vault-pki: the Platform's vaultIssuer owns the Vault issuer
    #     (decision 4), and the AppSet would need its own Vault annotations;
    #   - cilium-gateway-secondary: needs a second clusterbook reservation
    #     (fqdn-secondary), which a ClusterStack does not make.
    network = s.Profile {
        labels = {
            "network-platform" = "true"
            "network-platform/cert-manager-vault-pki" = "false"
            "network-platform/cilium-gateway-secondary" = "false"
        }
    }
    # platforms/security: external-secrets and kyverno. The stores AppSet is an
    # opt-in gate the stack derives from spec.secretStores.
    security = s.Profile {
        labels = {"security-platform" = "true"}
    }
    # platforms/storage with openebs as the StorageClass. Opt-out, so longhorn
    # and both nfs-csi entries are switched off — nfs-csi-storageclasses would
    # additionally wait on an nfs-config gate forever. cloudnative-pg is opt-in
    # and stays out of this profile.
    "storage-openebs" = s.Profile {
        labels = {
            "storage-platform" = "true"
            "storage-platform/longhorn" = "false"
            "storage-platform/nfs-csi-install" = "false"
            "storage-platform/nfs-csi-storageclasses" = "false"
        }
        # What openebs provides, for the platforms that ask for a class.
        annotations = {
            "observability-platform.stuttgart-things.com/storage-class" = "openebs-hostpath"
            "homerun2-platform.stuttgart-things.com/storage-class" = "openebs-hostpath"
        }
    }
    # platforms/observability: kube-prometheus-stack. Its secrets-config gate,
    # secret-store and webhook key are derived by the stack from clusterSecrets
    # and spec.secretStores; alert-webhook-url is environment and stays on the XR.
    observability = s.Profile {
        labels = {"observability-platform" = "true"}
    }
    # platforms/base: reloader.
    base = s.Profile {
        labels = {"base-platform" = "true"}
    }
    # --- app platforms, with the secrets they read (#464) --------------------
    # platforms/homerun2: redis-stack, omni-pitcher, catchers, scout. Gated on
    # homerun2-platform.stuttgart-things.com/secrets-config, which the stack
    # derives once the AppSecretProfile resolves; the storage class comes from a
    # storage profile.
    homerun2 = s.Profile {
        labels = {"homerun2-platform" = "true"}
        appSecrets = ["homerun2"]
    }
    # platforms/tabletennis: ONE Application that ships schmetterpause, zaehlwerk
    # and the light-catcher (apps/tabletennis/install). So it needs all three
    # declarations, and zaehlwerk's and tabletennis' reads of homerun2's entry
    # make homerun2 a required profile in the same order — xplane-cluster fails
    # the render otherwise.
    tabletennis = s.Profile {
        labels = {"tabletennis-platform" = "true"}
        appSecrets = ["schmetterpause", "zaehlwerk", "tabletennis"]
    }
}
