# The catalog registry.
#
# KCL has no file globbing, so every app is registered explicitly: add
# apps/<name>.k, then one import and one entry here. Keeping it manual is the
# point — adding an app to the platform is a reviewable two-line diff.
import .apps.cert_manager as cert_manager
import .apps.dapr as dapr
import .apps.headlamp as headlamp
import .apps.trust_manager as trust_manager
import schema as s

catalog: {str:s.App} = {
    "cert-manager" = cert_manager.certManager
    dapr = dapr.dapr
    headlamp = headlamp.headlamp
    "trust-manager" = trust_manager.trustManager
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
