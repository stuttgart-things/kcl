import ..schema as s

# vault — https://github.com/stuttgart-things/flux/tree/main/apps/vault
#
# NOT the fleet's Vault. This installs a Vault ON the cluster; the fleet's own
# lives at vault.infra.sthings-vsphere and is consumed, not managed, by
# `platform.vaultIssuer`. Worth stating because the names collide in
# conversation more often than in configuration.
#
# No admin password among the required variables, unlike harbor or argo-cd:
# Vault initialises itself and unsealing is the autounseal component's job, not
# a value someone types into an XR.
vault: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/apps/vault"
    defaultVersion = "v1.20.0"
    components = [
        s.Component {
            name = "install"
            path = "./"
            wrapsHelmRelease = True
            timeout = "15m"
            # ISSUER_* name the cert-manager Issuer the ingress certificate is
            # requested from — a decision about trust, so no source. The domain
            # is a fact and is discovered.
            requiredSubstitutions = [
                "ISSUER_KIND"
                "ISSUER_NAME"
                "VAULT_INGRESS_DOMAIN"
                "VAULT_INGRESS_HOSTNAME"
            ]
            substitutionSources = {
                VAULT_INGRESS_DOMAIN = "ipReservation.domain"
            }
        }
        # Gateway API route, for clusters that front their services with a
        # Gateway rather than an Ingress. Optional because the install already
        # brings an Ingress path.
        s.Component {
            name = "httproute"
            path = "./httproute"
            optional = True
            dependsOn = ["install"]
            requiredSubstitutions = ["VAULT_DOMAIN", "VAULT_HOSTNAME"]
            substitutionSources = {
                VAULT_DOMAIN = "ipReservation.domain"
            }
        }
        # Auto-unseal operator. Optional and deliberately so: a Vault that
        # unseals itself is a convenience with a real trade-off, and a cluster
        # should have to ask for it.
        s.Component {
            name = "autounseal"
            path = "./autounseal"
            optional = True
            dependsOn = ["install"]
            wrapsHelmRelease = True
            timeout = "15m"
        }
    ]
}
