import ..schema as s

# cert-manager — https://github.com/stuttgart-things/flux/tree/main/infra/cert-manager
#
# The artifact root (base) installs ONLY the cert-manager controller with no
# Vault dependency (flux#190). ./components/install is the same controller as a
# standalone component — kept because other artifacts depend on it by name
# (e.g. trust-manager -> cert-manager:install).
#
# The legacy Vault AppRole ClusterIssuer is the OPT-IN approle-issuer component
# (needs VAULT_* substitutions). New clusters leave it off and use a tokenless
# Kubernetes-auth ClusterIssuer provisioned out-of-band (VaultK8sAuth).
#
# selfsigned is optional and off unless enabled; it needs a domain.
# (components/extra-certificate exists too — add it when something needs it.)
certManager: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/infra/cert-manager"
    defaultVersion = "v1.22.2"
    components = [
        s.Component {
            name = "install"
            path = "./components/install"
            wrapsHelmRelease = True
            timeout = "15m"
        }
        s.Component {
            name = "selfsigned"
            path = "./components/selfsigned"
            optional = True
            dependsOn = ["install"]
            requiredSubstitutions = ["CERT_MANAGER_SELFSIGNED_DOMAIN"]
        }
        s.Component {
            name = "approle-issuer"
            path = "./components/approle-issuer"
            optional = True
            dependsOn = ["install"]
            wrapsHelmRelease = True
            timeout = "15m"
            requiredSubstitutions = [
                "VAULT_ADDR"
                "VAULT_PKI_PATH"
                "VAULT_CA_BUNDLE"
                "VAULT_ROLE_ID"
                "VAULT_SECRET_ID"
            ]
        }
    ]
}
