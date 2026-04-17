"""
Example: Argo CD AppProject granting cluster-wide access to an external cluster.

Render:
    kcl run examples/app_project_xplane.k
"""
import ..v1alpha1.argoproj_io_v1alpha1_app_project as appproject_mod

project = appproject_mod.AppProject {
    metadata = {
        name = "xplane-test"
        namespace = "argocd"
    }
    spec = {
        sourceRepos = ["*"]
        destinations = [
            {
                server = "https://10.100.136.192:34360"
                namespace = "*"
            }
        ]
        clusterResourceWhitelist = [
            {
                group = "*"
                kind = "*"
            }
        ]
    }
}

items = [project]
