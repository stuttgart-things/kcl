# Create Flux Kustomization Template

Create a new Flux Kustomization template for the claim-flux-kustomizations module.

## Input

The user provides:
- **App/component name** (e.g., "argocd", "metallb")
- **Flux repo path** (e.g., `./apps/argocd`, `./infra/metallb`) — or the path to the actual Kustomize component in the flux repo to inspect
- **Type**: infrastructure or app
- **Dependencies** (optional): comma-separated list of Kustomization names this depends on
- **Substitution variables** (optional): if not provided, inspect the target YAML files for `${VAR:-default}` patterns

If the user provides a path to actual flux manifests, read them to discover substitution variables automatically.

## Steps

### 1. Discover substitution variables

If the user points to actual manifest files (e.g., `/home/sthings/projects/apps/flux/apps/argocd/`), read all YAML files there and extract `${VARIABLE_NAME:-default}` patterns. These become the postBuild substitutions.

### 2. Add dispatcher block to main.k

Add a new `if _templateName == "<name>":` block in `main.k`, placed alphabetically among the other template blocks (before the `gitrepository` template which is always last).

Follow this exact pattern from existing templates:

```kcl
# Template: <Display Name> (<brief description>)
if _templateName == "<name>":
    flux.Kustomization {
        metadata = v1.ObjectMeta {
            name = _name if _name != "flux-kustomization" else "<name>"
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-flux-kustomizations"
                "template": "<name>"
            }
            labels = {
                "app.kubernetes.io/managed-by": "flux"
                "kustomization.stuttgart-things.com/type": "<type>"
            }
        }
        spec = flux.KustomizeToolkitFluxcdIoV1KustomizationSpec {
            interval = _interval if _interval != "5m" else "1h"
            retryInterval = _retryInterval if _retryInterval else "1m"
            timeout = _timeout if _timeout else "5m"
            prune = _prune
            wait = True
            force = _force
            suspend = _suspend
            sourceRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecSourceRef {
                kind = _sourceRefKind
                name = _sourceRefName if _sourceRefName else "flux-apps"
                if _sourceRefNamespace:
                    namespace = _sourceRefNamespace
            }
            path = _path if _path != "./" else "<default-path>"
            if _dependsOnNames:
                dependsOn = [
                    flux.KustomizeToolkitFluxcdIoV1KustomizationSpecDependsOnItems0 {
                        name = depName
                        if _dependsOnNamespace:
                            namespace = _dependsOnNamespace
                    }
                    for depName in _dependsOnNames
                ]
            postBuild = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecPostBuild {
                substitute = {
                    "VAR_NAME": str(_varName)
                }
            }
            if _kubeConfigSecretRef:
                kubeConfig = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecKubeConfig {
                    secretRef = flux.KustomizeToolkitFluxcdIoV1KustomizationSpecKubeConfigSecretRef {
                        name = _kubeConfigSecretRef
                        if _kubeConfigSecretKey:
                            key = _kubeConfigSecretKey
                    }
                }
            if _serviceAccountName:
                serviceAccountName = _serviceAccountName
        }
    }
```

### 3. Add parameters to main.k

Add template-specific parameter variables in the parameters section of `main.k` (around lines 80-230), grouped with a comment:

```kcl
# <Name> specific parameters (for <name> template)
_varName = _spec?.varName or option("varName") or "<default>"
```

### 4. Create ClaimTemplate YAML

Create `templates/flux-kustomization-<name>.yaml` following this pattern:

```yaml
---
apiVersion: resources.stuttgart-things.com/v1alpha1
kind: ClaimTemplate
metadata:
  name: flux-kustomization-<name>
  title: Flux Kustomization <Display Name>
  description: <One-line description>
  tags:
    - flux
    - kustomization
    - <name>
    - <type>
spec:
  type: kustomization
  source: oci://ghcr.io/stuttgart-things/claim-flux-kustomizations
  tag: <current version from kcl.mod>
  parameters:
    - name: templateName
      title: Template
      type: string
      default: <name>
    - name: name
      title: Resource Name
      type: string
      default: <name>
      pattern: "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$"
    - name: namespace
      title: Namespace
      type: string
      default: flux-system
      pattern: "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$"
    - name: sourceRefKind
      title: Source Reference Kind
      type: string
      default: GitRepository
      enum:
        - GitRepository
        - OCIRepository
        - Bucket
    - name: sourceRefName
      title: Source Reference Name
      type: string
      default: flux-apps
      pattern: "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$"
    - name: sourceRefNamespace
      title: Source Reference Namespace
      type: string
      description: "Namespace of the source, defaults to Kustomization namespace"
    - name: path
      title: Path
      type: string
      default: "<default-path>"
    - name: interval
      title: Reconciliation Interval
      type: string
      default: "1h"
    - name: retryInterval
      title: Retry Interval
      type: string
      default: "1m"
    - name: timeout
      title: Timeout
      type: string
      default: "5m"
    - name: prune
      title: Enable Pruning
      type: boolean
      default: true
    - name: force
      title: Force Recreation
      type: boolean
      default: false
    - name: suspend
      title: Suspend Reconciliation
      type: boolean
      default: false
    - name: dependsOnNames
      title: Dependency Names
      type: string
      default: "<default-depends-on or empty>"
      description: "Comma-separated list of Kustomization names this depends on"
    - name: dependsOnNamespace
      title: Dependencies Namespace
      type: string
    # Add template-specific parameters here with descriptions
    # referencing the substitution variable name, e.g.:
    # description: "Version (SOME_VAR_NAME)"
    - name: kubeConfigSecretRef
      title: KubeConfig Secret
      type: string
      description: "Secret containing kubeconfig for remote cluster deployment"
    - name: kubeConfigSecretKey
      title: KubeConfig Secret Key
      type: string
      default: "value"
    - name: serviceAccountName
      title: Service Account
      type: string
```

### 5. Update README

Add the new template to the appropriate section in `templates/README.md`.

### 6. Verify

Run `kcl run . -D templateName=<name> -D sourceRefName=flux-apps --dry-run` to validate the template compiles.

## Important

- **Do NOT create a dedicated `.k` file** for the template. All templates are dispatched through `main.k`.
- The standalone `.k` files (`gitops.k`, `infrastructure.k`, `crossplane.k`, `cert-manager.k`, `clusterbook.k`, `gitrepository.k`) are base/legacy templates — new templates only need a dispatcher block in `main.k` + a ClaimTemplate YAML.
- Always use `str()` to wrap parameter values in the substitute block.
- Always include `kubeConfigSecretRef` and `serviceAccountName` support for remote cluster deployments.
- Get the current module version from `kcl.mod` for the ClaimTemplate `tag` field.
