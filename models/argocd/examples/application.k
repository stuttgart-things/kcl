"""
Example: Argo CD Application targeting a Git repo.

Render:
    kcl run examples/application.k
"""
import ..v1alpha1.argoproj_io_v1alpha1_application as app_mod

# Inputs (override via -D key=value)
appName = option("appName") or "guestbook"
destNamespace = option("destNamespace") or "guestbook"
repoURL = option("repoURL") or "https://github.com/argoproj/argocd-example-apps.git"
targetRevision = option("targetRevision") or "HEAD"
path = option("path") or "guestbook"

application = app_mod.Application {
    metadata = {
        name = appName
        namespace = "argocd"
    }
    spec = {
        project = "default"
        destination = {
            server = "https://kubernetes.default.svc"
            namespace = destNamespace
        }
        source = {
            repoURL = repoURL
            targetRevision = targetRevision
            path = path
        }
        syncPolicy = {
            automated = {
                prune = True
                selfHeal = True
            }
        }
    }
}

items = [application]
