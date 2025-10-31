# stuttgart-things/kcl/kubernetes/helmfile

## USAGE

```bash
kcl run main.k
```

```bash
kcl run main.k -D apps=cilium
```

## Details & Output Structure

This module generates a Helmfile configuration for Kubernetes deployments using KCL. The output includes:

- `helmDefaults`: Global Helm settings (verify, wait, timeout, recreatePods, force)
- `helmfiles`: List of Helmfile entries, each with:
  - `path`: Git URL to the Helmfile template
  - `values`: List of value overrides for the deployment (e.g. config, configureLB)

### Example Output

```yaml
helmDefaults:
  verify: false
  wait: true
  timeout: 600
  recreatePods: false
  force: true
helmfiles:
  - path: git::https://github.com/stuttgart-things/helm.git@infra/cilium.yaml.gotmpl
    values:
      - config: kind
      - configureLB: true
  - path: git::https://github.com/stuttgart-things/helm.git@infra/cert-manager.yaml.gotmpl
    values:
      - config: selfsigned
```

### Customization

- Use `-D apps=<name>` to select specific apps for deployment.
- Edit the KCL file to add/remove Helmfile entries or change values as needed.

For more advanced usage, see the schema definitions in `schema.k`.