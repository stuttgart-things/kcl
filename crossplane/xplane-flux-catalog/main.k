# The catalog registry.
#
# KCL has no file globbing, so every app is registered explicitly: add
# apps/<name>.k, then one import and one entry here. Keeping it manual is the
# point — adding an app to the platform is a reviewable two-line diff.
import .apps.cert_manager as cert_manager
import .apps.cilium as cilium
import .apps.dapr as dapr
import .apps.external_secrets as external_secrets
import .apps.headlamp as headlamp
import .apps.machinery as machinery
import .apps.nfs_csi as nfs_csi
import .apps.openebs as openebs
import .apps.tekton as tekton
import .apps.trust_manager as trust_manager
import .apps.vault as vault
import schema as s

catalog: {str:s.App} = {
    "cert-manager" = cert_manager.certManager
    cilium = cilium.cilium
    dapr = dapr.dapr
    "external-secrets" = external_secrets.externalSecrets
    headlamp = headlamp.headlamp
    machinery = machinery.machinery
    "nfs-csi" = nfs_csi.nfsCsi
    openebs = openebs.openebs
    tekton = tekton.tekton
    "trust-manager" = trust_manager.trustManager
    vault = vault.vault
}

names = sorted(catalog)

_known = ", ".join(names)

# Look up an app by name. Fails loudly on an unknown name rather than silently
# returning an empty app that would render zero Kustomizations.
get = lambda name: str -> s.App {
    # KCL does NOT interpolate ${} inside assert messages — it prints the
    # placeholder literally. Concatenate so the message names the app.
    assert name in catalog, "unknown app '" + name + "' — known: " + _known
    catalog[name]
}
