# Argo CD ApplicationSet (KCL generator)

Flexible KCL module that renders an Argo CD `ApplicationSet` manifest. Every
field is overridable via `-D` flags, so the module can be invoked directly
from the OCI registry without cloning the repo or shipping override files.

Completes the trio with [`argocd-app-project`](../argocd-app-project/) and
[`argocd-application`](../argocd-application/).

## Quick start (OCI, standalone)

The defaults reproduce the `kro` ApplicationSet with a git-file generator,
multi-source template (Helm chart + `$values` ref), and Go-template-enabled
destination substitution:

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0
```

Override just the name and keep the rest:

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D name=my-appset
```

Pipe directly to `kubectl`:

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  | kubectl apply -f -
```

## Parameters

All parameters are passed with `-D <name>=<value>`. Lists and dicts must be
valid JSON (wrap the whole arg in single quotes).

### Metadata

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `str` | `"kro"` | `metadata.name` |
| `namespace` | `str` | `"argocd"` | `metadata.namespace` |
| `labels` | `{str: str}` | `{}` | `metadata.labels` |
| `annotations` | `{str: str}` | `{}` | `metadata.annotations` |
| `finalizers` | `[str]` | `[]` | `metadata.finalizers` |

### Templating engine

| Parameter | Type | Default | Description |
|---|---|---|---|
| `goTemplate` | `bool` | `True` | `spec.goTemplate` |
| `goTemplateOptions` | `[str]` | `["missingkey=error"]` | `spec.goTemplateOptions` |

### Generators

| Parameter | Type | Default | Description |
|---|---|---|---|
| `generators` | `[{…}]` | git-file generator for the `kro` example | `spec.generators` — pass as JSON |

Each entry is a generator dict keyed by type (`git`, `list`, `cluster`,
`matrix`, `merge`, `pullRequest`, `clusters`, `clusterDecisionResource`,
`scmProvider`, `plugin`, …) — the module passes the structure through to
Argo unchanged.

### Template metadata (produced `Application.metadata`)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `templateName` | `str` | `"kro-{{ .cluster.name }}"` | `template.metadata.name` |
| `templateNamespace` | `str` | `""` (omitted) | `template.metadata.namespace` |
| `templateLabels` | `{str: str}` | `{"app.kubernetes.io/part-of":"kro","cluster":"{{ .cluster.name }}"}` | `template.metadata.labels` |
| `templateAnnotations` | `{str: str}` | `{}` (omitted) | `template.metadata.annotations` |
| `templateFinalizers` | `[str]` | `[]` (omitted) | `template.metadata.finalizers` |
| `templateMetadata` | `{…}` | derived from above | Entire `template.metadata` dict |

### Template spec (produced `Application.spec`)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `project` | `str` | `"default"` | `template.spec.project` |
| `source` | `{…}` | `{}` (omitted) | Single-source `template.spec.source` |
| `sources` | `[{…}]` | multi-source (Helm chart + `$values` ref) | `template.spec.sources` |
| `destServer` | `str` | `"{{ .cluster.server }}"` | `template.spec.destination.server` |
| `destName` | `str` | `""` (omitted) | `template.spec.destination.name` |
| `destNamespace` | `str` | `"{{ .kro.namespace }}"` | `template.spec.destination.namespace` |
| `destination` | `{…}` | derived from above | Entire `template.spec.destination` dict |
| `prune` | `bool` | `True` | `template.spec.syncPolicy.automated.prune` |
| `selfHeal` | `bool` | `True` | `template.spec.syncPolicy.automated.selfHeal` |
| `allowEmpty` | `bool` | omitted | `template.spec.syncPolicy.automated.allowEmpty` |
| `automated` | `{…}` | derived | `template.spec.syncPolicy.automated` |
| `syncOptions` | `[str]` | `["CreateNamespace=true","ServerSideApply=true","Replace=true"]` | `template.spec.syncPolicy.syncOptions` |
| `retry` | `{…}` | `{}` (omitted) | `template.spec.syncPolicy.retry` |
| `templateSyncPolicy` | `{…}` | derived | Entire `template.spec.syncPolicy` |
| `templateSpec` | `{…}` | derived | Entire `template.spec` |

### Whole template override

| Parameter | Type | Default | Description |
|---|---|---|---|
| `template` | `{metadata,spec}` | derived | Replace the whole `spec.template` in one go |

### Top-level extras

| Parameter | Type | Default | Description |
|---|---|---|---|
| `syncPolicyTopLevel` | `{…}` | `{}` (omitted) | `spec.syncPolicy` (appset-level, e.g. `preserveResourcesOnDeletion`) |
| `strategy` | `{…}` | `{}` (omitted) | `spec.strategy` (rolling sync) |
| `preservedFields` | `{…}` | `{}` (omitted) | `spec.preservedFields` |
| `templatePatch` | `str` | `""` (omitted) | `spec.templatePatch` |

## Common `-D` recipes

### Fan out a single-source app to a list of clusters

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D name=multi-cluster-guestbook \
  -D 'generators=[{"list":{"elements":[
        {"cluster":"dev","url":"https://1.2.3.4","namespace":"guestbook-dev"},
        {"cluster":"prod","url":"https://5.6.7.8","namespace":"guestbook-prod"}
      ]}}]' \
  -D templateName='{{ .cluster }}-guestbook' \
  -D 'templateLabels={"cluster":"{{ .cluster }}"}' \
  -D 'sources=[]' \
  -D 'source={"repoURL":"https://github.com/argoproj/argocd-example-apps.git","path":"guestbook","targetRevision":"HEAD"}' \
  -D destServer='{{ .url }}' \
  -D destNamespace='{{ .namespace }}' \
  -D 'syncOptions=["CreateNamespace=true"]'
```

### Cluster generator (all Argo-registered clusters)

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D name=cluster-addons \
  -D 'generators=[{"clusters":{}}]' \
  -D templateName='addons-{{ .name }}' \
  -D destServer='{{ .server }}' \
  -D destNamespace=addons
```

### Matrix generator combining git directories × clusters

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D name=apps-per-cluster \
  -D 'generators=[{"matrix":{"generators":[
        {"git":{"repoURL":"https://github.com/org/repo.git","revision":"HEAD","directories":[{"path":"apps/*"}]}},
        {"clusters":{}}
      ]}}]' \
  -D templateName='{{ path.basename }}-{{ .name }}'
```

### Disable Go-templating (use `{{values}}`-style handlebars)

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D goTemplate=false \
  -D 'goTemplateOptions=[]' \
  -D templateName='{{values}}-app'
```

### Preserve Applications when the set is deleted

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D 'syncPolicyTopLevel={"preserveResourcesOnDeletion":true}'
```

### Rolling sync strategy

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D 'strategy={"type":"RollingSync","rollingSync":{"steps":[
        {"matchExpressions":[{"key":"env","operator":"In","values":["dev"]}]},
        {"matchExpressions":[{"key":"env","operator":"In","values":["prod"]}],"maxUpdate":"10%"}
      ]}}'
```

### Whole-template override (pass the full template dict)

```bash
kcl run oci://ghcr.io/stuttgart-things/argocd-application-set --tag 0.1.0 \
  -D 'template={"metadata":{"name":"{{ .name }}-app"},"spec":{"project":"default","source":{"repoURL":"…","path":"…","targetRevision":"HEAD"},"destination":{"server":"{{ .server }}","namespace":"default"}}}'
```

## Tips for `-D` with JSON

- Wrap the whole arg in single quotes so the shell doesn't eat the braces:
  `-D 'generators=[{"git":{"repoURL":"…"}}]'`.
- Use double quotes **inside** the JSON (required by the parser).
- Argo Go-template expressions like `{{ .cluster.name }}` live in string
  values, so they pass through the JSON parser untouched — just quote them
  in the shell.
- To drop a block entirely, pass an empty dict/list: `-D 'sources=[]'`,
  `-D 'syncPolicyTopLevel={}'`.

## Local development

```bash
# Clone the repo, then:
cd kubernetes/argocd-application-set

# Use defaults (renders the kro ApplicationSet)
kcl run main.k

# Pass overrides on the CLI
kcl run main.k -D name=my-appset -D templateName='my-{{ .cluster.name }}'

# Or use an override file
kcl run main.k examples/kro.k
kcl run main.k examples/list.k
```

## Publishing to OCI

From the repo root:

```bash
task push-module MODULE_DIR=kubernetes/argocd-application-set NEW_VERSION=0.1.0
```

Then check the tag landed:

```bash
oras repo tags ghcr.io/stuttgart-things/argocd-application-set
```

## Files

- [main.k](main.k) — `_var = option("…") or <default>` for each field; outputs `items = [_applicationSet]`
- [schema.k](schema.k) — typed `ApplicationSet`, `ApplicationSetSpec` (with flexible `generators` / `template` passthrough)
- [examples/kro.k](examples/kro.k) — recreates the target `kro` ApplicationSet
- [examples/list.k](examples/list.k) — list generator fanning out a single-source app
