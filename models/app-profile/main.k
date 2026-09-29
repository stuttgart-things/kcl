"""
AppProfile: one catalog app, both halves.

An AppProfile sits next to a component in the stuttgart-things/flux catalog
(`<bundle>/components/<app>/profile.yaml`). It lists the postBuild.substitute
vars a cluster may set for the app and the Secret its substituteFrom reads,
with how each value is made. blueprints `render-cluster-apps` renders the
bundle Kustomization and the SOPS-encrypted Secret from it
(stuttgart-things/blueprints#206).

This schema checks the SHAPE of a profile:

    kcl vet profile.yaml main.k -s AppProfile --format yaml

Whether the vars and keys match the component is checked in the catalog
(hack/check-app-profiles.py), because that needs the component itself.

Every pattern is written into its check, and no check calls a lambda:
`kcl vet` (kcl 0.12.4) does not evaluate module-level variables, so a
pattern or lambda defined at the top would be empty inside a check -- and a
regex check against it passes everything. Quantifiers run over private
attributes, because `kcl fmt` rewrites `all k in (x or {}) {`.
Keys are variable names because substituteFrom turns every key into one.
"""

import regex

schema AppProfile:
    """One catalog app: its component, the vars it reads, the Secret it needs."""
    kind: "AppProfile"
    metadata: Metadata
    spec: AppProfileSpec

    check:
        spec.component == "../components/" + metadata.name, "spec.component must be ../components/<metadata.name>"

schema Metadata:
    name: str

    check:
        regex.match(name, r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$"), "metadata.name must be a DNS label"

schema AppProfileSpec:
    # Catalog bundle the component belongs to
    bundle: "apps-platform" | "infra-platform" | "cicd-platform"
    # Component path relative to the bundle root, ../components/<app>
    component: str
    # postBuild.substitute vars a cluster may set for this app
    vars?: {str:Var}
    # Secrets the component reads via substituteFrom, all in flux-system
    secrets?: [Secret]
    _varNames = [k for k in vars] if vars else []
    _secretNames = [s.name for s in secrets] if secrets else []

    check:
        all k in _varNames {
            regex.match(k, r"^[A-Za-z_][A-Za-z0-9_]*$")
        }, "vars keys must be variable names"
        len({n: 0 for n in _secretNames}) == len(_secretNames), "secret names must be unique"

schema Var:
    # The cluster must set it (the component defaults to a set-... placeholder)
    required?: bool
    # Value used when the cluster sets none
    default?: str

schema Secret:
    name: str
    type?: str
    # key -> value: a literal string, a ref+sops:// or ref+vault:// string,
    # or one of generate / ref / value
    data: {str:str | Generated | Ref | Literal}

    # A bare string starting with ref+ is a reference, so it must parse as one.
    _bareRefs: [str] = [str(v) for _, v in data if typeof(v) == "str" and str(v).startswith("ref+")]

    check:
        regex.match(name, r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$"), "secret name must be a DNS label"
        len(data) > 0, "secret ${name} has no data"
        all k in data {
            regex.match(k, r"^[A-Za-z_][A-Za-z0-9_]*$")
        }, "secret ${name}: keys must be variable names, substituteFrom turns them into variables"
        all r in _bareRefs {
            regex.match(r, r"^ref\+(sops|vault)://[^#]+#/.+$")
        }, "secret ${name}: a ref+ value must be ref+sops://<path>#/<pointer> or ref+vault://<path>#/<field>"

schema Generated:
    generate: Generate

schema Generate:
    $type: "password" | "alnum" | "hex" | "base64" | "uuid"
    length?: int
    # Replaces the alphabet of password or alnum
    charset?: str

    check:
        length == None or length > 0, "length must be positive"
        $type != "password" or length == None or charset or length >= 4, "a password needs length >= 4 to hold every character class"
        not charset or $type in ["password", "alnum"], "charset only applies to password and alnum"

schema Ref:
    ref: str

    check:
        regex.match(ref, r"^ref\+(sops|vault)://[^#]+#/.+$"), "ref must be ref+sops://<path>#/<pointer> or ref+vault://<path>#/<field>"

schema Literal:
    value: str

