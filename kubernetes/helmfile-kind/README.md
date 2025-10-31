# stuttgart-things/kcl/kubernetes/helmfile

This module generates a Helmfile configuration for Kubernetes deployments using KCL. The output includes:

- `helmDefaults`: Global Helm settings (verify, wait, timeout, recreatePods, force)
- `helmfiles`: List of Helmfile entries, each with:
  - `path`: Git URL to the Helmfile template
  - `values`: List of value overrides for the deployment (e.g. config, configureLB)

## USAGE

```bash
kcl run main.k
```

```bash
kcl run main.k -D apps=cilium
```

```bash
kcl run main.k -D apps=cilium -D cilium_configure_lb=False
```
