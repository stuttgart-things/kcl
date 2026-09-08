# crossplane-provider-terraform models

Generated KCL models for the Crossplane [Terraform provider](https://github.com/upbound/provider-terraform)
CRDs (`tf.upbound.io`). Schemas only — there is no runnable entrypoint.

## Contents

| package | schemas |
|---|---|
| `v1beta1` | `Workspace` |

`k8s/` holds the vendored `apimachinery` types the schema references.

## Use

```python
import models.v1beta1.tf_upbound_io_v1beta1_workspace as tf

workspace = tf.Workspace {
    metadata.name = "example"
    spec = {
        forProvider = {
            source = "Inline"
            module = "..."
        }
    }
}
```

## Note on the package name

`kcl.mod` names this package `models`, not `crossplane-provider-terraform`, so the
import path is `models.v1beta1...`. The parent directory
(`models/crossplane-provider-terraform`) is a separate KCL module that wraps
these schemas.
