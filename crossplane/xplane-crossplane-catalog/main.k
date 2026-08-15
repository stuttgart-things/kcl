# The profile registry.
#
# Mirrors xplane-flux-catalog: no file globbing in KCL, so every profile is
# registered explicitly. One profile today; the shape exists because a seed and
# a full machinery cluster will not want the same package set.
import .profiles.machinery as machinery
import schema as s

catalog: {str:s.Profile} = {
    machinery = machinery.machinery
}

names = sorted(catalog)

_known = ", ".join(names)

# Look up a profile by name. Fails loudly rather than returning an empty profile
# that would render a Crossplane install with no packages — which looks like a
# working cluster until the first XR finds no XRD.
get = lambda name: str -> s.Profile {
    # KCL does NOT interpolate ${} inside assert messages.
    assert name in catalog, "unknown profile '" + name + "' — known: " + _known
    catalog[name]
}

# Packages of one kind, in declaration order. Consumers apply Providers before
# Functions before Configurations: a Configuration whose functions are missing
# reconciles into an error rather than waiting.
byKind = lambda profile: s.Profile, kind: str -> [s.Package] {
    [p for p in profile.packages if p.kind == kind]
}

# Everything the profile's packages bring in without being named. Not applied by
# anyone — this is the deny-list the roots-only rule is checked against, and the
# honest answer to "what is actually on this cluster".
transitive = lambda profile: s.Profile -> [str] {
    sorted({d: "" for p in profile.packages for d in p.pulls})
}

# The CR name Crossplane itself derives from a package path: registry dropped,
# path segments joined with "-", tag stripped. `provider-helm` has always been
# installed as `crossplane-contrib-provider-helm` for this reason.
#
# Using it for everything a dependsOn can also name is what makes the #247 Lock
# collision impossible rather than merely unlikely. The resolver keys on the
# SOURCE, so an existing node satisfies a dependency no matter what it is
# called — but during an UPGRADE the entry is briefly gone, the resolver
# auto-installs the dependency under this derived name, and a short-named CR
# then collides with it. If the CR already carries this name, the two are the
# same object and there is no window.
derivedName = lambda package: str -> str {
    _rest = package.split("/")[1::]
    _last = _rest[-1].split(":")[0]
    "-".join(_rest[:-1:] + [_last])
}
