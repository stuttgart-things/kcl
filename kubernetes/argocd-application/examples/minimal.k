# Example: minimal in-cluster Application with automated sync
#
# Usage:
#   kcl run main.k examples/minimal.k

_name = "guestbook"
_namespace = "argocd"
_project = "default"

_repoURL = "https://github.com/argoproj/argocd-example-apps.git"
_path = "guestbook"

_destNamespace = "guestbook"
