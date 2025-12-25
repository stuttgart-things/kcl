"""
Crossplane CompositeResourceDefinition (XRD) v2 main configuration
File: main.k
Usage: kcl main.k -D group=resources.example.com -D kind=MyResource -D plural=myresources -D singular=myresource
"""

import .schema  # Relative import for schema.k in the same directory

# Configuration variables (underscore prefix prevents them from being exported)
# Metadata configuration - name is required
_group = option("group")
_kind = option("kind")
_plural = option("plural")
_singular = option("singular")

# Construct name from group and plural if not explicitly provided
_name = option("name") or "${_plural}.${_group}"

_labels = option("labels")
_annotations = option("annotations")

# Spec configuration
_deletePolicy = option("deletePolicy") or "Foreground"
_scope = option("scope") or "Namespaced"

# Names configuration - optional
_categories = option("categories")
_shortNames = option("shortNames")

# Build the XRD
_xrd = schema.CompositeResourceDefinition {
    metadata = schema.Metadata {
        name = _name
        **({labels = _labels} if _labels != None and len(_labels) > 0 else {})
        **({annotations = _annotations} if _annotations != None and len(_annotations) > 0 else {})
    }
    spec = schema.XRDSpec {
        group = _group
        defaultCompositeDeletePolicy = _deletePolicy
        scope = _scope
        names = schema.Names {
            kind = _kind
            plural = _plural
            singular = _singular
            **({categories = _categories} if _categories != None and len(_categories) > 0 else {})
            **({shortNames = _shortNames} if _shortNames != None and len(_shortNames) > 0 else {})
        }
    }
}

# Output XRD fields at root level
apiVersion = _xrd.apiVersion
kind = _xrd.kind
metadata = _xrd.metadata
spec = _xrd.spec
