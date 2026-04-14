# crossplane-provider-kubernetes

KCL models for the [Crossplane Kubernetes Provider](https://github.com/crossplane-contrib/provider-kubernetes),
covering both the cluster-scoped `kubernetes.crossplane.io` API group and the
namespaced `kubernetes.m.crossplane.io` (Crossplane v2) variant.

Generated from CRDs at commit
[`9f86181`](https://github.com/crossplane-contrib/provider-kubernetes/tree/9f8618189b0e26a2e7b061942d39632f41b1af9b/package/crds).

## CRD sources

**`kubernetes.crossplane.io`** (cluster-scoped):

- [Object (v1alpha1, v1alpha2)](https://github.com/crossplane-contrib/provider-kubernetes/blob/main/package/crds/kubernetes.crossplane.io_objects.yaml)
- [ObservedObjectCollection (v1alpha1)](https://github.com/crossplane-contrib/provider-kubernetes/blob/main/package/crds/kubernetes.crossplane.io_observedobjectcollections.yaml)
- [ProviderConfig (v1alpha1)](https://github.com/crossplane-contrib/provider-kubernetes/blob/main/package/crds/kubernetes.crossplane.io_providerconfigs.yaml)
- [ProviderConfigUsage (v1alpha1)](https://github.com/crossplane-contrib/provider-kubernetes/blob/main/package/crds/kubernetes.crossplane.io_providerconfigusages.yaml)

**`kubernetes.m.crossplane.io`** (namespaced, Crossplane v2):

- ClusterProviderConfig, Object, ObservedObjectCollection, ProviderConfig,
  ProviderConfigUsage (v1alpha1) — see
  [package/crds](https://github.com/crossplane-contrib/provider-kubernetes/tree/main/package/crds)

## Package layout

```
v1alpha1/            # kubernetes.crossplane.io/v1alpha1
v1alpha1/kubernetesm # kubernetes.m.crossplane.io/v1alpha1 (subpkg)
v1alpha2/            # kubernetes.crossplane.io/v1alpha2 (Object)
```

## Usage

```toml
# kcl.mod
[dependencies]
crossplane-provider-kubernetes = {
  oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-kubernetes",
  tag = "0.1.0"
}
```

```py
import crossplane_provider_kubernetes.v1alpha2 as k8sv2
import crossplane_provider_kubernetes.v1alpha1.kubernetesm as k8sm

# Cluster-scoped Object (v1alpha2)
obj: k8sv2.Object = {
    metadata = {
        name = "example-cm"
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = "example"
                    namespace = "default"
                }
                data = {
                    key = "value"
                }
            }
        }
        providerConfigRef = {
            name = "default"
        }
    }
}

# Namespaced Object (Crossplane v2, kubernetes.m.crossplane.io)
nsObj: k8sm.Object = {
    metadata = {
        name = "example-cm-ns"
        namespace = "default"
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = "example-ns"
                    namespace = "default"
                }
                data = {
                    key = "value"
                }
            }
        }
        providerConfigRef = {
            kind = "ClusterProviderConfig"
            name = "default"
        }
    }
}
```
