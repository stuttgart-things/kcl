# main.k
import .schema

# Metadata — override via -D or by reassigning in a .k override file
_name = option("name") or "xplane-test"
_namespace = option("namespace") or "argocd"
_labels = option("labels") or {}
_annotations = option("annotations") or {}

# Spec — sensible defaults; override any field
_description = option("description") or ""
_sourceRepos = option("sourceRepos") or ["*"]
_sourceNamespaces = option("sourceNamespaces") or []

_destinations = option("destinations") or [
    {server = "https://kubernetes.default.svc", namespace = "*"}
]

_clusterResourceWhitelist = option("clusterResourceWhitelist") or [
    {group = "*", kind = "*"}
]
_clusterResourceBlacklist = option("clusterResourceBlacklist") or []
_namespaceResourceWhitelist = option("namespaceResourceWhitelist") or []
_namespaceResourceBlacklist = option("namespaceResourceBlacklist") or []

_metadata = schema.ObjectMeta {
    name = _name
    namespace = _namespace
    labels = _labels if _labels else Undefined
    annotations = _annotations if _annotations else Undefined
}

_spec = schema.AppProjectSpec {
    description = _description if _description else Undefined
    sourceRepos = _sourceRepos
    sourceNamespaces = _sourceNamespaces if _sourceNamespaces else Undefined
    destinations = _destinations
    clusterResourceWhitelist = _clusterResourceWhitelist if _clusterResourceWhitelist else Undefined
    clusterResourceBlacklist = _clusterResourceBlacklist if _clusterResourceBlacklist else Undefined
    namespaceResourceWhitelist = _namespaceResourceWhitelist if _namespaceResourceWhitelist else Undefined
    namespaceResourceBlacklist = _namespaceResourceBlacklist if _namespaceResourceBlacklist else Undefined
}

_appProject = schema.AppProject {
    metadata = _metadata
    spec = _spec
}

items = [_appProject]
