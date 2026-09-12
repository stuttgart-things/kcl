# main.k
import .schema

# Metadata — override via -D or by reassigning in a .k override file
_name = option("name") or "philly"
_namespace = option("namespace") or ""
_labels = option("labels") or {}
_annotations = option("annotations") or {}

# Spec — clusterbook fields. networkKey + providerConfigRef apply to
# default/classic clusters; for clusterType=kind they are intentionally
# omitted from the rendered manifest (the operator allocates differently).
_clusterType = option("clusterType") or ""
_isKind = _clusterType == "kind"

# Registration-only: register the cluster with ArgoCD and reserve NOTHING.
# kind reaches it implicitly (the operator keys off clusterType); -D
# skipReservation=true reaches it for any clusterType. Both are the same code
# path from here on, which is why every reservation field below tests
# _isRegistrationOnly rather than _isKind.
_skipReservation = option("skipReservation")
_isRegistrationOnly = _isKind or _skipReservation == True

# THE DEFAULT IS A LAB SUBNET, so it must not apply where nothing reserves.
# 10.31.101 is LabUL's; left to fire on a registration-only LabDA cluster it
# would render another lab's network as this cluster's, and -- via the CRD rule
# that a networkKey implies a providerConfigRef -- turn a registration into a
# reservation nobody asked for.
_networkKey = option("networkKey") or ("10.31.101" if not _isRegistrationOnly else "")

# A CONTRADICTION IS NOT A PREFERENCE. Every reservation field below is
# suppressed under skipReservation, so passing one anyway used to be dropped
# without a word -- the caller asked for an address out of 10.100.136, got a CR
# that reserves nothing, and no output said which of the two won. The schema
# checks cannot see this: by then the field is already gone. So it is caught
# here, where both values still exist.
assert not (_skipReservation == True and option("networkKey")), "skipReservation=true and networkKey are contradictory -- registration-only reserves from no pool. Drop one."
assert not (_skipReservation == True and option("providerConfigRef")), "skipReservation=true and providerConfigRef are contradictory -- no clusterbook call is made. Drop one."
assert not (_skipReservation == True and option("providerConfigName")), "skipReservation=true and providerConfigName are contradictory -- no clusterbook call is made. Drop one."
assert not (_skipReservation == True and option("createDNS") == True), "skipReservation=true and createDNS=true are contradictory -- there is no reserved address to point a record at. Drop one."
assert not (_skipReservation == True and option("releaseOnDelete") == True), "skipReservation=true and releaseOnDelete=true are contradictory -- nothing was reserved, so nothing is released. Drop one."
_clusterName = option("clusterName") or _name
_argocdNamespace = option("argocdNamespace") or "argocd"

# kind-only LB IP range (docker-bridge carve-out). Both -DlbRangeStart and
# -DlbRangeStop must be provided to render a non-empty lbRange; otherwise it
# is omitted and clusterbook-operator will reject a kind CR without it.
_lbRangeStart = option("lbRangeStart") or ""
_lbRangeStop = option("lbRangeStop") or ""
_lbRange = schema.LbRange {
    start = _lbRangeStart
    stop = _lbRangeStop
} if _lbRangeStart and _lbRangeStop else Undefined

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

# Selector labels merged onto the ArgoCD cluster Secret. Two ways to set them:
#   * `clusterLabels` — a full {str:str} map override (power users / -D JSON).
#   * `platformFeatures` — a list of platform-gate keys; each becomes
#     "<key>": "true". This is the form-friendly path (claim-machinery-api
#     multiselect) since the ClaimTemplate parameter schema has no map type.
# A selected feature stamps `"<key>": "true"`; unselected keys are simply
# omitted (ApplicationSets gate on the "true" value, so absent == off).
_platformFeatures = option("platformFeatures") or []
_featureLabels = {f: "true" for f in _platformFeatures}

# Base labels: an explicit clusterLabels override always wins. Otherwise fall
# back to the lab/role defaults ONLY when no platform features were selected, so
# a platform claim isn't polluted with env=lab/role=mgmt it never asked for.
_defaultClusterLabels = {
    "env" = "lab"
    "role" = "mgmt"
    "auto-project" = "true"
}
_baseClusterLabels = option("clusterLabels") or (_defaultClusterLabels if not _platformFeatures else {})
_clusterLabels = _baseClusterLabels | _featureLabels

# Free-form annotations merged onto the ArgoCD cluster Secret. Useful
# for AppSets that read chart values via
# `{{ index .metadata.annotations "..." }}` — e.g. cert-manager-vault-pki
# reads `clusterbook.stuttgart-things.com/{vault-server, vault-pki-path,
# vault-token-secret}`. Operator-managed annotations (cluster-name, ip,
# fqdn, zone, lb-range-*) win on conflict at reconcile time.
_clusterAnnotations = option("clusterAnnotations") or {}

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
    networkKey = _networkKey if _networkKey and not _isRegistrationOnly else Undefined
    clusterName = _clusterName
    providerConfigRef = _providerConfigRef if not _isRegistrationOnly else Undefined
    clusterType = _clusterType if _clusterType else Undefined
    lbRange = _lbRange
    argocdNamespace = _argocdNamespace if _argocdNamespace else Undefined
    createDNS = _createDNS if _createDNS != None and not _isRegistrationOnly else Undefined
    preserveKubeconfigServer = _preserveKubeconfigServer if _preserveKubeconfigServer != None else Undefined
    useFQDNAsServer = _useFQDNAsServer if _useFQDNAsServer != None else Undefined
    serverSubdomain = _serverSubdomain if _serverSubdomain else Undefined
    serverPort = _serverPort if _serverPort else Undefined
    kubeconfigSecretRef = _kubeconfigSecretRef if not _useExisting else Undefined
    existingSecretRef = _existingSecretRef if _useExisting else Undefined
    labels = _clusterLabels if _clusterLabels else Undefined
    annotations = _clusterAnnotations if _clusterAnnotations else Undefined
    # Not emitted under skipReservation: there is no reservation to release,
    # and the operator does not read it there. Emitting `releaseOnDelete: true`
    # on a CR that reserved nothing reads like a safeguard that exists.
    #
    # Gated on the FLAG and not on _isRegistrationOnly, so the kind path renders
    # exactly what it rendered before. It is equally inert there, but changing
    # it would be a second change riding along with this one.
    releaseOnDelete = _releaseOnDelete if _releaseOnDelete != None and _skipReservation != True else Undefined
    skipReservation = True if _skipReservation == True else Undefined
}

_clusterbookCluster = schema.ClusterbookCluster {
    metadata = _metadata
    spec = _spec
}

# Render a single ClusterbookCluster document (not a list/items wrapper)
_clusterbookCluster
