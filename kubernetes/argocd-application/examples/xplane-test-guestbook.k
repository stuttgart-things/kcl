# Example: recreate the xplane-test-guestbook Application
#
# Usage:
#   kcl run main.k examples/xplane-test-guestbook.k

_name = "xplane-test-guestbook"
_namespace = "argocd"

_project = "xplane-test"

_repoURL = "https://github.com/argoproj/argocd-example-apps.git"
_path = "guestbook"
_targetRevision = "HEAD"

_destServer = "https://10.100.136.192:34360"
_destNamespace = "guestbook"

_syncOptions = ["CreateNamespace=true"]
