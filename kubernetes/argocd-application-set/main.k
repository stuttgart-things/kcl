# main.k
import .schema

# Metadata — override via -D or by reassigning in a .k override file
_name = option("name") or "kro"
_namespace = option("namespace") or "argocd"
_labels = option("labels") or {}
_annotations = option("annotations") or {}
_finalizers = option("finalizers") or []

# Template engine
_goTemplate = option("goTemplate")
_goTemplateOptions = option("goTemplateOptions") or ["missingkey=error"]

# Generators — required, must be provided unless defaults are overridden
_generators = option("generators") or [
    {
        git = {
            repoURL = "https://github.com/stuttgart-things/flux.git"
            revision = "HEAD"
            files = [
                {path = "tests/argocd/kro/clusters/*/cluster.yaml"}
            ]
        }
    }
]

# Template — build from convenience vars when `template` is not passed whole
_templateName = option("templateName") or "kro-{{ .cluster.name }}"
_templateNamespace = option("templateNamespace") or ""
_templateLabels = option("templateLabels") or {
    "app.kubernetes.io/part-of" = "kro"
    "cluster" = "{{ .cluster.name }}"
}
_templateAnnotations = option("templateAnnotations") or {}
_templateFinalizers = option("templateFinalizers") or []

_project = option("project") or "default"

# Source(s) for the generated Applications
_source = option("source") or {}
_sources = option("sources") or [
    {
        repoURL = "registry.k8s.io/kro/charts"
        chart = "kro"
        targetRevision = "{{ .kro.chartVersion }}"
        helm = {
            releaseName = "kro"
            valueFiles = [
                "$values/tests/argocd/kro/clusters/{{ .cluster.name }}/values.yaml"
            ]
        }
    }
    {
        repoURL = "https://github.com/stuttgart-things/flux.git"
        targetRevision = "HEAD"
        ref = "values"
    }
]

# Destination
_destServer = option("destServer") or "{{ .cluster.server }}"
_destName = option("destName") or ""
_destNamespace = option("destNamespace") or "{{ .kro.namespace }}"
_destination = option("destination") or {
    server = _destServer if _destServer else Undefined
    name = _destName if _destName else Undefined
    namespace = _destNamespace
}

# Sync policy for the generated Applications
_prune = option("prune")
_selfHeal = option("selfHeal")
_allowEmpty = option("allowEmpty")
_automated = option("automated") or {
    prune = _prune if _prune != None else True
    selfHeal = _selfHeal if _selfHeal != None else True
    allowEmpty = _allowEmpty if _allowEmpty != None else Undefined
}
_syncOptions = option("syncOptions") or [
    "CreateNamespace=true"
    "ServerSideApply=true"
    "Replace=true"
]
_retry = option("retry") or {}
_templateSyncPolicy = option("templateSyncPolicy") or {
    automated = _automated if _automated else Undefined
    syncOptions = _syncOptions if _syncOptions else Undefined
    retry = _retry if _retry else Undefined
}

_templateMetadata = option("templateMetadata") or {
    name = _templateName
    namespace = _templateNamespace if _templateNamespace else Undefined
    labels = _templateLabels if _templateLabels else Undefined
    annotations = _templateAnnotations if _templateAnnotations else Undefined
    finalizers = _templateFinalizers if _templateFinalizers else Undefined
}

_templateSpec = option("templateSpec") or {
    project = _project
    source = _source if _source and not _sources else Undefined
    sources = _sources if _sources else Undefined
    destination = _destination
    syncPolicy = _templateSyncPolicy if _templateSyncPolicy else Undefined
}

_template = option("template") or {
    metadata = _templateMetadata
    spec = _templateSpec
}

# Top-level spec extras
_syncPolicy = option("syncPolicyTopLevel") or {}
_strategy = option("strategy") or {}
_preservedFields = option("preservedFields") or {}
_templatePatch = option("templatePatch") or ""

_metadata = schema.ObjectMeta {
    name = _name
    namespace = _namespace
    labels = _labels if _labels else Undefined
    annotations = _annotations if _annotations else Undefined
    finalizers = _finalizers if _finalizers else Undefined
}

_spec = schema.ApplicationSetSpec {
    goTemplate = _goTemplate if _goTemplate != None else True
    goTemplateOptions = _goTemplateOptions if _goTemplateOptions else Undefined
    generators = _generators
    template = _template
    syncPolicy = _syncPolicy if _syncPolicy else Undefined
    strategy = _strategy if _strategy else Undefined
    preservedFields = _preservedFields if _preservedFields else Undefined
    templatePatch = _templatePatch if _templatePatch else Undefined
}

_applicationSet = schema.ApplicationSet {
    metadata = _metadata
    spec = _spec
}

items = [_applicationSet]
