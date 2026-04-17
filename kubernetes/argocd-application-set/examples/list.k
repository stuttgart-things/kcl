# Example: simple list generator fanning out an app to multiple clusters
#
# Usage:
#   kcl run main.k examples/list.k

_name = "multi-cluster-guestbook"

_generators = [
    {
        list = {
            elements = [
                {cluster = "dev", url = "https://1.2.3.4", namespace = "guestbook-dev"}
                {cluster = "prod", url = "https://5.6.7.8", namespace = "guestbook-prod"}
            ]
        }
    }
]

_templateName = "{{ .cluster }}-guestbook"
_templateLabels = {cluster = "{{ .cluster }}"}

_project = "default"

_sources = []
_source = {
    repoURL = "https://github.com/argoproj/argocd-example-apps.git"
    path = "guestbook"
    targetRevision = "HEAD"
}

_destServer = "{{ .url }}"
_destNamespace = "{{ .namespace }}"

_syncOptions = ["CreateNamespace=true"]
