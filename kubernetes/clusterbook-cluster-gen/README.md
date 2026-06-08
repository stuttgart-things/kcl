# ClusterbookCluster (KCL generator)

Flexible KCL module that renders a `clusterbook.stuttgart-things.com/v1alpha1`
`ClusterbookCluster` manifest. Every field is overridable via `-D` flags, so
the module can be invoked directly from the OCI registry without cloning the
repo or shipping override files.

The schema mirrors the upstream CRD in
[stuttgart-things/clusterbook-operator](https://github.com/stuttgart-things/clusterbook-operator/blob/main/kcl/crds/clusterbook.stuttgart-things.com_clusterbookclusters.yaml).
For the type-safe model package generated directly from the CRD see
[`models/clusterbook-cluster`](../../models/clusterbook-cluster/).

## ClaimTemplates

[`templates/`](templates/) ships `ClaimTemplate` specs for the
[claim-machinery-api](https://github.com/stuttgart-things/claim-machinery-api) /
IDP scaffolder. The API renders each parameter as a `-D <name>=<value>` flag
against this module, so the form fields map directly onto the `option(...)`
inputs `main.k` already reads.

| Template | File | Cluster type | Prompts for |
|---|---|---|---|
| **Developer** | `templates/clusterbook-cluster-developer.yaml` | default/classic | name, network pool |
| **Detailed** | `templates/clusterbook-cluster-detailed.yaml` | default/classic | + clusterName, provider config, ArgoCD namespace, kubeconfig secret, DNS, FQDN/server URL |
| **Platform** | `templates/clusterbook-cluster-platform.yaml` | default/classic | management cluster + a multiselect of network-/storage-platform components |
| **Kind** | `templates/clusterbook-cluster-kind.yaml` | kind | name, LoadBalancer IP range |

For `kind`, `clusterType=kind` is fixed (hidden) and `networkKey` /
`providerConfigRef` are omitted automatically — the operator carves the
LoadBalancer range from the docker bridge instead.

### Platform feature gates (cluster Secret labels)

The `labels` stamped onto the ArgoCD cluster Secret are the platform feature
gates that drive the per-component ApplicationSets (e.g.
`network-platform/cilium-lb: "true"`). The `ClaimTemplate` parameter schema has
no map type, so the **Platform** template exposes them as a `multiselect`
`platformFeatures` list instead: each selected key is rendered as
`"<key>": "true"`. Unselected keys are omitted — the ApplicationSets gate on the
`"true"` value, so absent is equivalent to off. Keep the umbrella gates
(`network-platform`, `storage-platform`) selected for their sub-components to
take effect.

Power users can still pass the full map directly with
`-D 'clusterLabels={"network-platform":"true",...}'`; an explicit `clusterLabels`
override is used as the base and any `platformFeatures` are merged on top. When
no `platformFeatures` are selected, the `clusterLabels` default
(`env`/`role`/`auto-project`) is preserved for backward compatibility.

## Quick start (OCI, standalone)

Recreate the `philly` cluster from the labul lab with a single command:

```bash
kcl run oci://ghcr.io/stuttgart-things/clusterbook-cluster-gen --tag 0.1.0 \
  -D name=philly \
  -D networkKey=10.31.101 \
  -D clusterName=philly \
  -D createDNS=true \
  -D preserveKubeconfigServer=true \
  -D releaseOnDelete=true \
  -D kubeconfigSecretName=philly \
  -D kubeconfigSecretNamespace=argocd \
  -D argocdNamespace=argocd \
  -D providerConfigName=default \
  -D 'clusterLabels={"env":"lab","role":"mgmt","auto-project":"true"}'
```

Renders:

```yaml
items:
- apiVersion: clusterbook.stuttgart-things.com/v1alpha1
  kind: ClusterbookCluster
  metadata:
    name: philly
  spec:
    networkKey: '10.31.101'
    clusterName: philly
    providerConfigRef:
      name: default
    argocdNamespace: argocd
    createDNS: true
    preserveKubeconfigServer: true
    kubeconfigSecretRef:
      name: philly
      namespace: argocd
    labels:
      env: lab
      role: mgmt
      auto-project: 'true'
    releaseOnDelete: true
```

Pipe directly to `kubectl`:

```bash
kcl run oci://ghcr.io/stuttgart-things/clusterbook-cluster-gen --tag 0.1.0 \
  -D name=philly \
  -D networkKey=10.31.101 \
  -D createDNS=true \
  -D preserveKubeconfigServer=true \
  -D releaseOnDelete=true \
  | kubectl apply -f -
```

## Parameters

All parameters are passed with `-D <name>=<value>`. Maps and dicts must be
valid JSON (use single quotes around the whole arg to keep the shell out of it).

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `str` | `"philly"` | `metadata.name` |
| `namespace` | `str` | `""` (omitted — `ClusterbookCluster` is cluster-scoped) | `metadata.namespace` |
| `labels` | `{str: str}` | `{}` | `metadata.labels` |
| `annotations` | `{str: str}` | `{}` | `metadata.annotations` |
| `networkKey` | `str` | `"10.31.101"` | clusterbook network pool, e.g. `"10.31.103"` |
| `clusterName` | `str` | value of `name` | clusterbook cluster identifier and ArgoCD cluster name |
| `argocdNamespace` | `str` | `"argocd"` | namespace where the ArgoCD cluster Secret is written |
| `createDNS` | `bool` | omitted | ask clusterbook to create a wildcard DNS record |
| `preserveKubeconfigServer` | `bool` | omitted | keep `data.server` set to the kubeconfig's URL (precedence over `useFQDNAsServer`) |
| `useFQDNAsServer` | `bool` | omitted | rewrite `data.server` to the clusterbook FQDN (requires `createDNS=true`) |
| `serverSubdomain` | `str` | omitted (operator default `"api"`) | substitution label for the wildcard FQDN when `useFQDNAsServer=true` |
| `serverPort` | `int` | omitted (operator default `6443`) | port appended to the ArgoCD server URL |
| `kubeconfigSecretName` | `str` | value of `name` | name of the kubeconfig Secret (managed mode) |
| `kubeconfigSecretNamespace` | `str` | value of `argocdNamespace` | namespace of the kubeconfig Secret |
| `kubeconfigSecretKey` | `str` | omitted (operator default `"kubeconfig"`) | data key inside the kubeconfig Secret |
| `kubeconfigSecretRef` | `{name,namespace,key?}` | built from the three fields above | full override |
| `existingSecretRef` | `{name,namespace}` | `{}` (omitted) | enrich-mode reference to an existing ArgoCD cluster Secret. Mutually exclusive with `kubeconfigSecretRef` — set this and the kubeconfig ref is omitted |
| `providerConfigName` | `str` | `"default"` | name for the auto-built `providerConfigRef` |
| `providerConfigRef` | `{name}` | `{name = providerConfigName}` | full override |
| `clusterLabels` | `{str: str}` | `{"env":"lab","role":"mgmt","auto-project":"true"}` (omitted when `platformFeatures` is set) | labels merged onto the ArgoCD cluster Secret (used for `ApplicationSet` selection) |
| `platformFeatures` | `[str]` | `[]` | platform-gate keys; each is stamped as `"<key>": "true"` and merged onto `clusterLabels` (form-friendly alternative to a raw map) |
| `releaseOnDelete` | `bool` | omitted | release the clusterbook IP reservation when the CR is deleted |

`kubeconfigSecretRef` and `existingSecretRef` are mutually exclusive — exactly
one is required, validated by a schema check.

## Common `-D` recipes

### Minimal — defaults (renders a `philly`-like cluster)

```bash
kcl run oci://ghcr.io/stuttgart-things/clusterbook-cluster-gen --tag 0.1.0 \
  -D createDNS=true \
  -D preserveKubeconfigServer=true \
  -D releaseOnDelete=true
```

### Different cluster, different network pool

```bash
kcl run oci://ghcr.io/stuttgart-things/clusterbook-cluster-gen --tag 0.1.0 \
  -D name=austin \
  -D networkKey=10.31.105 \
  -D clusterName=austin \
  -D createDNS=true \
  -D preserveKubeconfigServer=true \
  -D kubeconfigSecretName=austin-kubeconfig
```

### Use clusterbook FQDN as ArgoCD server URL

```bash
kcl run oci://ghcr.io/stuttgart-things/clusterbook-cluster-gen --tag 0.1.0 \
  -D name=denver \
  -D networkKey=10.31.103 \
  -D createDNS=true \
  -D useFQDNAsServer=true \
  -D serverSubdomain=api \
  -D serverPort=6443
```

### Enrich an existing ArgoCD cluster Secret

```bash
kcl run oci://ghcr.io/stuttgart-things/clusterbook-cluster-gen --tag 0.1.0 \
  -D name=denver \
  -D networkKey=10.31.103 \
  -D createDNS=true \
  -D 'existingSecretRef={"name":"denver-cluster","namespace":"argocd"}'
```

### Custom selector labels for ApplicationSets

```bash
kcl run oci://ghcr.io/stuttgart-things/clusterbook-cluster-gen --tag 0.1.0 \
  -D name=edge-1 \
  -D networkKey=10.31.110 \
  -D createDNS=true \
  -D preserveKubeconfigServer=true \
  -D 'clusterLabels={"env":"prod","role":"edge","region":"eu-west-1"}'
```

## Tips for `-D` with JSON

- Wrap the whole arg in single quotes so the shell doesn't eat the braces:
  `-D 'existingSecretRef={"name":"...","namespace":"argocd"}'`.
- Use double quotes **inside** the JSON (required by the JSON parser).
- Booleans and numbers are plain: `-D createDNS=true`, `-D serverPort=6443`.
- Strings are plain unless they'd collide with shell syntax.

## Local development

```bash
# Clone the repo, then:
cd kubernetes/clusterbook-cluster-gen

# Use defaults
kcl run main.k

# Pass overrides on the CLI
kcl run main.k \
  -D name=philly \
  -D createDNS=true \
  -D preserveKubeconfigServer=true \
  -D releaseOnDelete=true

# Or use an override file (reassigns the private _vars)
kcl run main.k examples/philly.k
kcl run main.k examples/enrich.k
```

Override files live in [`examples/`](examples/) and reassign the `_name`,
`_networkKey`, … vars defined in `main.k`. Later files win, so you can
combine them with extra `-D` flags.

## Publishing to OCI

From the repo root:

```bash
task push-module MODULE_DIR=kubernetes/clusterbook-cluster-gen NEW_VERSION=0.1.0
```

Then check the tag landed:

```bash
oras repo tags ghcr.io/stuttgart-things/clusterbook-cluster-gen
```

The CRD-derived model package publishes separately to
`ghcr.io/stuttgart-things/clusterbook-cluster`.

## Files

- [main.k](main.k) — `_var = option("…") or <default>` for each field; outputs `items = [_clusterbookCluster]`
- [schema.k](schema.k) — typed `ClusterbookCluster`, `ClusterbookClusterSpec`, `SecretRef`, `ProviderConfigRef`, `ObjectMeta`
- [examples/philly.k](examples/philly.k) — recreates the labul `philly` cluster
- [examples/enrich.k](examples/enrich.k) — enrich-mode variant with `useFQDNAsServer`
- [templates/](templates/) — `ClaimTemplate` specs (developer / detailed / platform / kind) for claim-machinery-api
