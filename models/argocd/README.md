# Argo CD KCL Module

Type-safe KCL schemas for Argo CD custom resources, generated from the official
upstream CRDs in [argoproj/argo-cd](https://github.com/argoproj/argo-cd/tree/master/manifests/crds).

Includes:

- `Application` (`argoproj.io/v1alpha1`)
- `ApplicationSet` (`argoproj.io/v1alpha1`)
- `AppProject` (`argoproj.io/v1alpha1`)

## Installation

```bash
# Add module to your KCL project
kcl mod add oci://ghcr.io/stuttgart-things/argocd

# Or add to kcl.mod manually
[dependencies]
argocd = { oci = "oci://ghcr.io/stuttgart-things/argocd", tag = "0.0.1" }
```

## Usage

### Application

```python
import argocd.v1alpha1.argoproj_io_v1alpha1_application as app_mod

application = app_mod.Application {
    metadata = {
        name = "guestbook"
        namespace = "argocd"
    }
    spec = {
        project = "default"
        destination = {
            server = "https://kubernetes.default.svc"
            namespace = "guestbook"
        }
        source = {
            repoURL = "https://github.com/argoproj/argocd-example-apps.git"
            targetRevision = "HEAD"
            path = "guestbook"
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
```

### AppProject

```python
import argocd.v1alpha1.argoproj_io_v1alpha1_app_project as appproject_mod

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
    }
}

items = [project]
```

### ApplicationSet

```python
import argocd.v1alpha1.argoproj_io_v1alpha1_application_set as appset_mod

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
```

## Rendering

Render one of the example files to YAML using `kcl run`:

```bash
# Render a file that exports `items`
kcl run examples/application.k

# Render and pipe to kubectl for a dry-run
kcl run examples/application.k | kubectl apply --dry-run=client -f -

# Render with parameters from the CLI
kcl run examples/application.k -D appName=guestbook -D destNamespace=dev

# Render the tests (useful as a smoke test)
kcl run tests/argocd_test.k
```

## Testing

```bash
# Run all schema tests in this module
kcl test ./...
```

Expected output:

```
test_application: PASS
test_app_project: PASS
test_application_set: PASS
PASS: 3/3
```

## CRD Source

- **Upstream**: [argoproj/argo-cd](https://github.com/argoproj/argo-cd)
- **CRD URLs**:
  - https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/crds/application-crd.yaml
  - https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/crds/applicationset-crd.yaml
  - https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/crds/appproject-crd.yaml
- **Conversion Tool**: `kcl import -m crd` (same tool wrapped by the
  `create-object-module-from-crd` Taskfile task)

## Re-generating Models

```bash
# Download the upstream CRDs
mkdir -p /tmp/argo-crds && cd /tmp/argo-crds
for f in application-crd.yaml applicationset-crd.yaml appproject-crd.yaml; do
  curl -fsSL -O "https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/crds/$f"
done

# Convert to KCL schemas
cd models/argocd
kcl import -m crd \
  /tmp/argo-crds/application-crd.yaml \
  /tmp/argo-crds/applicationset-crd.yaml \
  /tmp/argo-crds/appproject-crd.yaml

# The importer writes into ./models — flatten it back to the module root
mv models/v1alpha1 . && mv models/k8s . && rm -rf models
```
