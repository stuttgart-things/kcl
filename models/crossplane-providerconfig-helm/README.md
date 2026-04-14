# crossplane-providerconfig-helm

KCL models for the Crossplane Helm Provider's namespaced managed API group
(`helm.m.crossplane.io/v1beta1`) from [crossplane-contrib/provider-helm](https://github.com/crossplane-contrib/provider-helm).

## CRD sources

- [`helm.m.crossplane.io/v1beta1` ProviderConfig](https://github.com/crossplane-contrib/provider-helm/blob/main/package/crds/helm.m.crossplane.io_providerconfigs.yaml)
- [`helm.m.crossplane.io/v1beta1` ProviderConfigUsage](https://github.com/crossplane-contrib/provider-helm/blob/main/package/crds/helm.m.crossplane.io_providerconfigusages.yaml)

```toml
# kcl.mod

# ..
[dependencies]
crossplane-providerconfig-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-providerconfig-helm", tag = "0.1.1" }
```

```py
import crossplane_providerconfig_helm.v1beta1 as v1beta1

# ProviderConfig using a kubeconfig secret
pc: v1beta1.ProviderConfig = {
    metadata = {
        name = "hello-world-helm"
        namespace = "crossplane-system"
    }
    spec = {
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = "crossplane-system"
                name = "kubeconfig-secret"
                key = "kubeconfig"
            }
        }
    }
}

# ProviderConfigUsage recording which managed resource consumes the config
pcu: v1beta1.ProviderConfigUsage = {
    metadata = {
        name = "hello-world-helm-usage"
        namespace = "crossplane-system"
    }
    providerConfigRef = {
        kind = "ProviderConfig"
        name = "hello-world-helm"
    }
    resourceRef = {
        apiVersion = "helm.m.crossplane.io/v1beta1"
        kind = "Release"
        name = "nginx-ns"
    }
}
```
