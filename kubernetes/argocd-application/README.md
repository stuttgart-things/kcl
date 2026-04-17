# Argo CD Application (KCL generator)

Flexible KCL module that renders an Argo CD `Application` manifest. Every
field is overridable via `-D` flags, so the module can be invoked directly
from the OCI registry without cloning the repo or shipping override files.

Sibling of [`argocd-app-project`](../argocd-app-project/) — pair the two to
provision a project and its apps from the same toolchain.

## Quick start (OCI, standalone)

Recreate the `xplane-test-guestbook` Application with a single command:

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=xplane-test-guestbook \
  -D project=xplane-test \
  -D destServer=https://10.100.136.192:34360 \
  -D destNamespace=guestbook
```

Renders:

```yaml
items:
- apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: xplane-test-guestbook
    namespace: argocd
  spec:
    project: xplane-test
    source:
      repoURL: https://github.com/argoproj/argocd-example-apps.git
      path: guestbook
      targetRevision: HEAD
    destination:
      server: https://10.100.136.192:34360
      namespace: guestbook
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
      syncOptions:
      - CreateNamespace=true
```

Pipe directly to `kubectl`:

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=xplane-test-guestbook \
  -D project=xplane-test \
  -D destServer=https://10.100.136.192:34360 \
  -D destNamespace=guestbook \
  | kubectl apply -f -
```

## Parameters

All parameters are passed with `-D <name>=<value>`. Lists and dicts must be
valid JSON (wrap the whole arg in single quotes).

### Metadata

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `str` | `"xplane-test-guestbook"` | `metadata.name` |
| `namespace` | `str` | `"argocd"` | `metadata.namespace` |
| `labels` | `{str: str}` | `{}` | `metadata.labels` |
| `annotations` | `{str: str}` | `{}` | `metadata.annotations` |
| `finalizers` | `[str]` | `[]` | `metadata.finalizers` (e.g. `["resources-finalizer.argocd.argoproj.io"]`) |

### Project & source

| Parameter | Type | Default | Description |
|---|---|---|---|
| `project` | `str` | `"default"` | AppProject name |
| `repoURL` | `str` | `"https://github.com/argoproj/argocd-example-apps.git"` | `spec.source.repoURL` |
| `path` | `str` | `"guestbook"` | `spec.source.path` |
| `targetRevision` | `str` | `"HEAD"` | `spec.source.targetRevision` |
| `chart` | `str` | `""` (omitted) | Helm chart name (for Helm repos) |
| `helm` | `{…}` | `{}` (omitted) | Full Helm source config |
| `kustomize` | `{…}` | `{}` (omitted) | Full Kustomize source config |
| `directory` | `{…}` | `{}` (omitted) | Directory source config |
| `plugin` | `{…}` | `{}` (omitted) | CMP plugin config |
| `source` | `{…}` | derived from above | Entire `spec.source` dict (overrides all source fields) |
| `sources` | `[{…}]` | `[]` (omitted) | Multi-source apps — when set, replaces `source` |

### Destination

| Parameter | Type | Default | Description |
|---|---|---|---|
| `destServer` | `str` | `"https://kubernetes.default.svc"` | `spec.destination.server` |
| `destName` | `str` | `""` (omitted) | `spec.destination.name` (mutually exclusive with `destServer`) |
| `destNamespace` | `str` | `"default"` | `spec.destination.namespace` |
| `destination` | `{…}` | derived from above | Entire `spec.destination` dict |

### Sync policy

| Parameter | Type | Default | Description |
|---|---|---|---|
| `prune` | `bool` | `True` | `syncPolicy.automated.prune` |
| `selfHeal` | `bool` | `True` | `syncPolicy.automated.selfHeal` |
| `allowEmpty` | `bool` | omitted | `syncPolicy.automated.allowEmpty` |
| `automated` | `{…}` | derived | Entire `syncPolicy.automated` dict |
| `syncOptions` | `[str]` | `["CreateNamespace=true"]` | `syncPolicy.syncOptions` |
| `retry` | `{…}` | `{}` (omitted) | `syncPolicy.retry` (`{limit, backoff}`) |
| `syncPolicy` | `{…}` | derived from above | Entire `syncPolicy` dict |

### Other

| Parameter | Type | Default | Description |
|---|---|---|---|
| `revisionHistoryLimit` | `int` | omitted | `spec.revisionHistoryLimit` |
| `info` | `[{name,value}]` | `[]` (omitted) | `spec.info` |

## Common `-D` recipes

### Minimal — in-cluster default project

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=my-app \
  -D destNamespace=my-app
```

### Helm chart from a Helm repo

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=kube-prometheus-stack \
  -D project=monitoring \
  -D repoURL=https://prometheus-community.github.io/helm-charts \
  -D chart=kube-prometheus-stack \
  -D targetRevision=65.1.0 \
  -D destNamespace=monitoring \
  -D 'helm={"releaseName":"kps","valueFiles":["values.yaml"]}'
```

### Pin to a git tag and disable auto-sync

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=pinned-app \
  -D targetRevision=v1.2.3 \
  -D 'syncPolicy={}'
```

### Retry with backoff

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=retrying-app \
  -D 'retry={"limit":5,"backoff":{"duration":"5s","factor":2,"maxDuration":"3m"}}'
```

### External cluster by name

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=prod-app \
  -D destName=prod-cluster \
  -D destNamespace=prod
```

### Extra sync options

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=apply-opts \
  -D 'syncOptions=["CreateNamespace=true","PrunePropagationPolicy=foreground","ApplyOutOfSyncOnly=true"]'
```

### Add a cleanup finalizer

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application --tag 0.1.0 \
  -D name=finalized-app \
  -D 'finalizers=["resources-finalizer.argocd.argoproj.io"]'
```

## Tips for `-D` with JSON

- Wrap the whole arg in single quotes: `-D 'helm={"releaseName":"..."}'`.
- Use double quotes **inside** the JSON (required by the parser).
- Scalars are plain: `-D name=foo`, `-D destNamespace=guestbook`.
- To drop a block entirely, pass an empty dict: `-D 'syncPolicy={}'`.

## Local development

```bash
# Clone the repo, then:
cd kubernetes/argocd-application

# Use defaults
kcl run main.k

# Pass overrides on the CLI
kcl run main.k -D name=xplane-test-guestbook -D project=xplane-test \
  -D destServer=https://10.100.136.192:34360 -D destNamespace=guestbook

# Or use an override file (reassigns the private _vars)
kcl run main.k examples/xplane-test-guestbook.k
kcl run main.k examples/minimal.k
```

## Publishing to OCI

From the repo root:

```bash
task push-module MODULE_DIR=kubernetes/argocd-application NEW_VERSION=0.1.0
```

Then check the tag landed:

```bash
oras repo tags ghcr.io/stuttgart-things/argocd-application
```

## Files

- [main.k](main.k) — `_var = option("…") or <default>` for each field; outputs `items = [_application]`
- [schema.k](schema.k) — typed `Application`, `ApplicationSpec`, `Source`, `Destination`, `SyncPolicy`
- [examples/xplane-test-guestbook.k](examples/xplane-test-guestbook.k) — recreates the paired AppProject example
- [examples/minimal.k](examples/minimal.k) — in-cluster default-project variant
