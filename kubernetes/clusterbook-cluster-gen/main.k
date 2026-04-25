# main.k
import .schema

# Metadata — override via -D or by reassigning in a .k override file
_name = option("name") or "philly"
_namespace = option("namespace") or ""
_labels = option("labels") or {}
_annotations = option("annotations") or {}

# Spec — required clusterbook fields
_networkKey = option("networkKey") or "10.31.101"
_clusterName = option("clusterName") or _name
_argocdNamespace = option("argocdNamespace") or "argocd"

# DNS / server URL behavior
_createDNS = option("createDNS")
_preserveKubeconfigServer = option("preserveKubeconfigServer")
_useFQDNAsServer = option("useFQDNAsServer")
_serverSubdomain = option("serverSubdomain") or ""
_serverPort = option("serverPort") or 0

# Mutually exclusive: pick one of kubeconfigSecretRef / existingSecretRef.
# Defaults populate kubeconfigSecretRef from -D kubeconfigSecretName/Namespace
# unless `existingSecretRef` is supplied as a dict.
_kubeconfigSecretName = option("kubeconfigSecretName") or _name
_kubeconfigSecretNamespace = option("kubeconfigSecretNamespace") or _argocdNamespace
_kubeconfigSecretKey = option("kubeconfigSecretKey") or ""
_kubeconfigSecretRef = option("kubeconfigSecretRef") or {
    name = _kubeconfigSecretName
    namespace = _kubeconfigSecretNamespace
    key = _kubeconfigSecretKey if _kubeconfigSecretKey else Undefined
}
_existingSecretRef = option("existingSecretRef") or {}

# providerConfigRef — defaults to {name = "default"}
_providerConfigName = option("providerConfigName") or "default"
_providerConfigRef = option("providerConfigRef") or {
    name = _providerConfigName
}

# Selector labels merged onto the ArgoCD cluster Secret
_clusterLabels = option("clusterLabels") or {
    "env" = "lab"
    "role" = "mgmt"
    "auto-project" = "true"
}

_releaseOnDelete = option("releaseOnDelete")

_metadata = schema.ObjectMeta {
    name = _name
    namespace = _namespace if _namespace else Undefined
    labels = _labels if _labels else Undefined
    annotations = _annotations if _annotations else Undefined
}

# Decide which secret ref to use: existingSecretRef wins if explicitly provided
_useExisting = True if _existingSecretRef else False

_spec = schema.ClusterbookClusterSpec {
    networkKey = _networkKey
    clusterName = _clusterName
    providerConfigRef = _providerConfigRef
    argocdNamespace = _argocdNamespace if _argocdNamespace else Undefined
    createDNS = _createDNS if _createDNS != None else Undefined
    preserveKubeconfigServer = _preserveKubeconfigServer if _preserveKubeconfigServer != None else Undefined
    useFQDNAsServer = _useFQDNAsServer if _useFQDNAsServer != None else Undefined
    serverSubdomain = _serverSubdomain if _serverSubdomain else Undefined
    serverPort = _serverPort if _serverPort else Undefined
    kubeconfigSecretRef = _kubeconfigSecretRef if not _useExisting else Undefined
    existingSecretRef = _existingSecretRef if _useExisting else Undefined
    labels = _clusterLabels if _clusterLabels else Undefined
    releaseOnDelete = _releaseOnDelete if _releaseOnDelete != None else Undefined
}

_clusterbookCluster = schema.ClusterbookCluster {
    metadata = _metadata
    spec = _spec
}

items = [_clusterbookCluster]
