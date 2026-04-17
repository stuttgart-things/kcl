# Example: recreate the kro ApplicationSet with a git-file generator
#
# Usage:
#   kcl run main.k examples/kro.k

_name = "kro"
_namespace = "argocd"

_goTemplate = True
_goTemplateOptions = ["missingkey=error"]

_generators = [
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

_templateName = "kro-{{ .cluster.name }}"
_templateLabels = {
    "app.kubernetes.io/part-of" = "kro"
    "cluster" = "{{ .cluster.name }}"
}

_project = "default"

_sources = [
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

_destServer = "{{ .cluster.server }}"
_destNamespace = "{{ .kro.namespace }}"

_syncOptions = [
    "CreateNamespace=true"
    "ServerSideApply=true"
    "Replace=true"
]
