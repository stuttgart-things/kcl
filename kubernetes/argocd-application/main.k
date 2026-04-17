# main.k
import .schema

# Metadata — override via -D or by reassigning in a .k override file
_name = option("name") or "xplane-test-guestbook"
_namespace = option("namespace") or "argocd"
_labels = option("labels") or {}
_annotations = option("annotations") or {}
_finalizers = option("finalizers") or []

# Project reference
_project = option("project") or "default"

# Source — override individual fields or the whole dict
_repoURL = option("repoURL") or "https://github.com/argoproj/argocd-example-apps.git"
_chart = option("chart") or ""
_pathOpt = option("path")
_path = _pathOpt if _pathOpt != None else ("" if _chart else "guestbook")
_targetRevision = option("targetRevision") or "HEAD"
_helm = option("helm") or {}
_kustomize = option("kustomize") or {}
_directory = option("directory") or {}
_plugin = option("plugin") or {}
_source = option("source") or {
    repoURL = _repoURL
    path = _path if _path else Undefined
    targetRevision = _targetRevision if _targetRevision else Undefined
    chart = _chart if _chart else Undefined
    helm = _helm if _helm else Undefined
    kustomize = _kustomize if _kustomize else Undefined
    directory = _directory if _directory else Undefined
    plugin = _plugin if _plugin else Undefined
}
_sources = option("sources") or []

# Destination
_destServer = option("destServer") or "https://kubernetes.default.svc"
_destName = option("destName") or ""
_destNamespace = option("destNamespace") or "default"
_destination = option("destination") or {
    server = _destServer if _destServer else Undefined
    name = _destName if _destName else Undefined
    namespace = _destNamespace
}

# Sync policy
_prune = option("prune")
_selfHeal = option("selfHeal")
_allowEmpty = option("allowEmpty")
_automated = option("automated") or {
    prune = _prune if _prune != None else True
    selfHeal = _selfHeal if _selfHeal != None else True
    allowEmpty = _allowEmpty if _allowEmpty != None else Undefined
}
_syncOptions = option("syncOptions") or ["CreateNamespace=true"]
_retry = option("retry") or {}
_syncPolicy = option("syncPolicy") or {
    automated = _automated if _automated else Undefined
    syncOptions = _syncOptions if _syncOptions else Undefined
    retry = _retry if _retry else Undefined
}

_revisionHistoryLimit = option("revisionHistoryLimit")
_info = option("info") or []

_metadata = schema.ObjectMeta {
    name = _name
    namespace = _namespace
    labels = _labels if _labels else Undefined
    annotations = _annotations if _annotations else Undefined
    finalizers = _finalizers if _finalizers else Undefined
}

_spec = schema.ApplicationSpec {
    project = _project
    source = _source if _source and not _sources else Undefined
    sources = _sources if _sources else Undefined
    destination = _destination
    syncPolicy = _syncPolicy if _syncPolicy else Undefined
    revisionHistoryLimit = _revisionHistoryLimit if _revisionHistoryLimit != None else Undefined
    info = _info if _info else Undefined
}

_application = schema.Application {
    metadata = _metadata
    spec = _spec
}

items = [_application]
