# The catalog registry.
#
# KCL has no file globbing, so every app is registered explicitly: add
# apps/<name>.k, then one import and one entry here. Keeping it manual is the
# point — adding an app to the platform is a reviewable two-line diff.
import .apps.dapr as dapr
import schema as s

catalog: {str:s.App} = {
    dapr = dapr.dapr
}

names = sorted(catalog)

_known = ", ".join(names)

# Look up an app by name. Fails loudly on an unknown name rather than silently
# returning an empty app that would render zero Kustomizations.
get = lambda name: str -> s.App {
    assert name in catalog, "unknown app '${name}' — known: ${_known}"
    catalog[name]
}
