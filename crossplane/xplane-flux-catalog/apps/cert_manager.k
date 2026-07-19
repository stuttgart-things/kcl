import ..schema as s

# cert-manager — https://github.com/stuttgart-things/flux/tree/main/infra/cert-manager
#
# The artifact root pulls a Vault PKI post-release (VAULT_ADDR, VAULT_ROLE_ID,
# VAULT_SECRET_ID, ...), so the catalog targets the components/ directories
# instead: ./components/install is a plain cert-manager install with no Vault
# dependency, which is what other artifacts depend on.
#
# selfsigned is optional and off unless enabled; it needs a domain.
# (components/extra-certificate exists too — add it when something needs it.)
certManager: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/infra/cert-manager"
    defaultVersion = "v1.18.1"
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
    ]
}
