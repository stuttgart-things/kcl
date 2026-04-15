# Tests for the argocd CRD schemas
import ..v1alpha1.argoproj_io_v1alpha1_application as app_mod
import ..v1alpha1.argoproj_io_v1alpha1_application_set as appset_mod
import ..v1alpha1.argoproj_io_v1alpha1_app_project as appproject_mod

# Test 1: Application renders with required fields
test_application = lambda {
    application = app_mod.Application {
        metadata = {
            name = "test-app"
            namespace = "argocd"
        }
        spec = {
            project = "default"
            destination = {
                server = "https://kubernetes.default.svc"
                namespace = "test-ns"
            }
            source = {
                repoURL = "https://github.com/example/repo.git"
                targetRevision = "HEAD"
                path = "manifests"
            }
        }
    }

    assert application.apiVersion == "argoproj.io/v1alpha1"
    assert application.kind == "Application"
    assert application.metadata.name == "test-app"
    assert application.metadata.namespace == "argocd"
    assert application.spec.project == "default"
    assert application.spec.destination.server == "https://kubernetes.default.svc"
    assert application.spec.destination.namespace == "test-ns"
    assert application.spec.source.repoURL == "https://github.com/example/repo.git"
}

# Test 2: AppProject renders with required fields
test_app_project = lambda {
    project = appproject_mod.AppProject {
        metadata = {
            name = "test-project"
            namespace = "argocd"
        }
        spec = {
            description = "Test project"
            sourceRepos = ["https://github.com/example/*"]
            destinations = [
                {
                    server = "https://kubernetes.default.svc"
                    namespace = "test-ns"
                }
            ]
        }
    }

    assert project.apiVersion == "argoproj.io/v1alpha1"
    assert project.kind == "AppProject"
    assert project.metadata.name == "test-project"
    assert project.spec.description == "Test project"
    assert len(project.spec.sourceRepos) == 1
    assert project.spec.sourceRepos[0] == "https://github.com/example/*"
    assert len(project.spec.destinations) == 1
    assert project.spec.destinations[0].namespace == "test-ns"
}

# Test 3: ApplicationSet renders with list generator
test_application_set = lambda {
    appset = appset_mod.ApplicationSet {
        metadata = {
            name = "test-appset"
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
                    name = "{{cluster}}-app"
                }
                spec = {
                    project = "default"
                    source = {
                        repoURL = "https://github.com/example/repo.git"
                        targetRevision = "HEAD"
                        path = "manifests"
                    }
                    destination = {
                        server = "{{url}}"
                        namespace = "default"
                    }
                }
            }
        }
    }

    assert appset.apiVersion == "argoproj.io/v1alpha1"
    assert appset.kind == "ApplicationSet"
    assert appset.metadata.name == "test-appset"
    assert len(appset.spec.generators) == 1
    assert len(appset.spec.generators[0].list.elements) == 2
    assert appset.spec.template.spec.project == "default"
}

# Run all tests
test_application()
test_app_project()
test_application_set()

print("All argocd schema tests passed")
