# Argo CD AppProject (KCL generator)

Flexible KCL module that renders an Argo CD `AppProject` manifest. Every
field is overridable via `-D` flags, so the module can be invoked directly
from the OCI registry without cloning the repo or shipping override files.

## Quick start (OCI, standalone)

Recreate the `xplane-test` project with a single command:

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-app-project --tag 0.1.0 \
  -D name=xplane-test \
  -D namespace=argocd \
  -D 'sourceRepos=["*"]' \
  -D 'destinations=[{"server":"https://10.100.136.192:34360","namespace":"*"}]' \
  -D 'clusterResourceWhitelist=[{"group":"*","kind":"*"}]'
```

Renders:

```yaml
items:
- apiVersion: argoproj.io/v1alpha1
  kind: AppProject
  metadata:
    name: xplane-test
    namespace: argocd
  spec:
    sourceRepos:
    - '*'
    destinations:
    - server: https://10.100.136.192:34360
      namespace: '*'
    clusterResourceWhitelist:
    - group: '*'
      kind: '*'
```

Pipe directly to `kubectl`:

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-app-project --tag 0.1.0 \
  -D name=xplane-test \
  -D 'destinations=[{"server":"https://10.100.136.192:34360","namespace":"*"}]' \
  | kubectl apply -f -
```

## Parameters

All parameters are passed with `-D <name>=<value>`. Lists and lists-of-objects
must be valid JSON (use single quotes around the whole arg to keep the shell
out of it).

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `str` | `"xplane-test"` | `metadata.name` |
| `namespace` | `str` | `"argocd"` | `metadata.namespace` |
| `labels` | `{str: str}` | `{}` | `metadata.labels` |
| `annotations` | `{str: str}` | `{}` | `metadata.annotations` |
| `description` | `str` | `""` (omitted) | Free-form project description |
| `sourceRepos` | `[str]` | `["*"]` | Allowed source repo URLs |
| `sourceNamespaces` | `[str]` | `[]` (omitted) | Namespaces that may host `Application` CRs |
| `destinations` | `[{server,name?,namespace}]` | `[{server="https://kubernetes.default.svc", namespace="*"}]` | Deploy targets |
| `clusterResourceWhitelist` | `[{group,kind}]` | `[{group="*", kind="*"}]` | Cluster-scoped kinds allowed |
| `clusterResourceBlacklist` | `[{group,kind}]` | `[]` (omitted) | Cluster-scoped kinds denied |
| `namespaceResourceWhitelist` | `[{group,kind}]` | `[]` (omitted) | Namespace-scoped kinds allowed |
| `namespaceResourceBlacklist` | `[{group,kind}]` | `[]` (omitted) | Namespace-scoped kinds denied |

## Common `-D` recipes

### Minimal — allow-all (defaults)

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-app-project --tag 0.1.0 \
  -D name=my-proj
```

### Lock down to a single repo and destination namespace

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-app-project --tag 0.1.0 \
  -D name=team-platform \
  -D description="Platform team project" \
  -D 'sourceRepos=["https://github.com/example/platform"]' \
  -D 'destinations=[{"server":"https://kubernetes.default.svc","namespace":"platform"}]' \
  -D 'clusterResourceWhitelist=[{"group":"","kind":"Namespace"}]' \
  -D 'namespaceResourceWhitelist=[{"group":"apps","kind":"Deployment"},{"group":"","kind":"ConfigMap"}]'
```

### External cluster by name (instead of `server`)

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-app-project --tag 0.1.0 \
  -D name=prod-apps \
  -D 'destinations=[{"name":"prod-cluster","namespace":"*"}]'
```

### Multiple destinations

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-app-project --tag 0.1.0 \
  -D name=multi-cluster \
  -D 'destinations=[
        {"server":"https://kubernetes.default.svc","namespace":"app-*"},
        {"server":"https://10.0.0.1:6443","namespace":"app-*"}
      ]'
```

### Add labels / annotations

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-app-project --tag 0.1.0 \
  -D name=tagged \
  -D 'labels={"team":"platform","env":"prod"}' \
  -D 'annotations={"owner":"sre@example.com"}'
```

## Tips for `-D` with JSON

- Wrap the whole arg in single quotes so the shell doesn't eat the braces:
  `-D 'destinations=[{"server":"..."}]'`
- Use double quotes **inside** the JSON (required by the JSON parser).
- Scalars are plain: `-D name=foo`, `-D namespace=argocd`.
- Booleans, numbers, and strings all work unquoted except when they'd collide
  with shell syntax.

## Local development

```bash
# Clone the repo, then:
cd kubernetes/argocd-app-project

# Use defaults
kcl run main.k

# Pass overrides on the CLI
kcl run main.k -D name=xplane-test \
  -D 'destinations=[{"server":"https://10.100.136.192:34360","namespace":"*"}]'

# Or use an override file (reassigns the private _vars)
kcl run main.k examples/xplane-test.k
kcl run main.k examples/minimal.k
```

Override files live in [`examples/`](examples/) and simply reassign the
`_name`, `_destinations`, … vars defined in `main.k`. Later files win, so
you can combine them with extra `-D` flags.

## Publishing to OCI

From the repo root:

```bash
task push-module MODULE_DIR=kubernetes/argocd-app-project NEW_VERSION=0.1.0
```

Then check the tag landed:

```bash
oras repo tags ghcr.io/stuttgart-things/argocd-app-project
```

## Files

- [main.k](main.k) — `_var = option("…") or <default>` for each field; outputs `items = [_appProject]`
- [schema.k](schema.k) — typed `AppProject`, `AppProjectSpec`, `Destination`, `ResourceKind`
- [examples/xplane-test.k](examples/xplane-test.k) — recreates the upstream example
- [examples/minimal.k](examples/minimal.k) — scoped-repo variant with resource whitelists
