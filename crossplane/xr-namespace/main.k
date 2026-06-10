"""
Example usage of the ManagedNamespace XR from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.

Templates
---------
minimal   : Simplest option - just a namespace name and a target cluster.
annotated : namespace name + target cluster + a generic, user-defined set of
            annotations applied to the Namespace. Reproduces the Harvester `vms`
            case by passing `field.cattle.io/projectId=<clusterId>:<projectId>`.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_managed_namespace as ns

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ns?.spec or {}

# Template selector
_templateName = option("templateName") or _params?.templateName or "minimal"  # Options: "minimal", "annotated"

# Common parameters
_name = _spec?.name or option("name") or _params?.name or "demo-ns"
_claimNamespace = _spec?.claimNamespace or option("claimNamespace") or _params?.claimNamespace or "default"
_providerConfig = _spec?.providerConfigRef or option("providerConfig") or _params?.providerConfig or "in-cluster"

# Generic annotations applied to the Namespace.
# Accepts either a native map (from `params` / `-D annotations='{...}'`) or a
# comma-separated `key=value` string (handy for `-D annotations=...` on the CLI),
# e.g. "field.cattle.io/projectId=c-cxgxd:p-sfgv4,owner=team-x".
_parseKeyValuePairs = lambda s: str -> {str:str} {
    {kv.split("=")[0].strip(): kv.split("=")[1].strip() for kv in s.split(",") if kv and "=" in kv}
}
_annotationsRaw = _spec?.annotations or option("annotations") or _params?.annotations or {}
_annotations: {str:str} = _parseKeyValuePairs(_annotationsRaw) if typeof(_annotationsRaw) == "str" else _annotationsRaw

# Minimal Template - just a namespace name and a target cluster.
if _templateName == "minimal":
    ns.ManagedNamespace {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = ns.ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpec {
            providerConfigRef = _providerConfig
            name = _name
        }
    }

# Annotated Template - namespace name + target cluster + generic annotations.
if _templateName == "annotated":
    ns.ManagedNamespace {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
        }

        spec = ns.ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpec {
            providerConfigRef = _providerConfig
            name = _name
            if _annotations:
                annotations = _annotations
        }
    }
