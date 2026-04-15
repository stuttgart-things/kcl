"""
Example: Argo CD ApplicationSet fanning out across clusters via a list generator.

Render:
    kcl run examples/application_set.k
"""
import ..v1alpha1.argoproj_io_v1alpha1_application_set as appset_mod

appset = appset_mod.ApplicationSet {
    metadata = {
        name = "multi-cluster-guestbook"
        namespace = "argocd"
    }
    spec = {
        generators = [
            {
                list = {
                    elements = [
                        {"cluster": "dev", "url": "https://1.2.3.4"}
                        {"cluster": "prod", "url": "https://5.6.7.8"}
                    ]
                }
            }
        ]
        template = {
            metadata = {
                name = "{{cluster}}-guestbook"
            }
            spec = {
                project = "default"
                source = {
                    repoURL = "https://github.com/argoproj/argocd-example-apps.git"
                    targetRevision = "HEAD"
                    path = "guestbook"
                }
                destination = {
                    server = "{{url}}"
                    namespace = "guestbook"
                }
            }
        }
    }
}

items = [appset]
