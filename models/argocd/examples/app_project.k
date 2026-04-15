"""
Example: Argo CD AppProject scoped to a single team.

Render:
    kcl run examples/app_project.k
"""
import ..v1alpha1.argoproj_io_v1alpha1_app_project as appproject_mod

project = appproject_mod.AppProject {
    metadata = {
        name = "team-platform"
        namespace = "argocd"
    }
    spec = {
        description = "Platform team project"
        sourceRepos = ["https://github.com/example/*"]
        destinations = [
            {
                server = "https://kubernetes.default.svc"
                namespace = "platform"
            }
        ]
        clusterResourceWhitelist = [
            {
                group = ""
                kind = "Namespace"
            }
        ]
        namespaceResourceWhitelist = [
            {
                group = "apps"
                kind = "Deployment"
            }
            {
                group = ""
                kind = "ConfigMap"
            }
        ]
    }
}

items = [project]
