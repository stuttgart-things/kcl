# crossplane-provider-helm

KCL models for the Crossplane Helm Provider ([crossplane-contrib/provider-helm](https://github.com/crossplane-contrib/provider-helm)).

## CRD sources

- [`helm.crossplane.io/v1beta1` Release](https://github.com/crossplane-contrib/provider-helm/blob/main/package/crds/helm.crossplane.io_releases.yaml)
- [`helm.m.crossplane.io/v1beta1` Release](https://github.com/crossplane-contrib/provider-helm/blob/main/package/crds/helm.m.crossplane.io_releases.yaml) (Crossplane v2 namespaced managed variant)

```toml
# kcl.mod

# ..
[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.3" }
```

import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_helm.models.v1beta1.helmm.helmm_crossplane_io_v1beta1_release as helmm

```py
# Example 1: Nginx deployment
nginx = helm.Release {
    apiVersion: "helm.crossplane.io/v1beta1"
    kind: "Release"
    metadata: {
        name: "nginx-prod"
    }
    spec: {
        providerConfigRef: { name: "default" }
        forProvider: {
            chart: {
                name: "nginx"
                repository: "https://charts.bitnami.com/bitnami"
                version: "15.0.0"
            }
            namespace: "production"
            values: {
                replicaCount: 3
                service: {
                    type: "LoadBalancer"
                }
            }
        }
    }
}
```

```py
# Example 2: PostgreSQL deployment
postgres = helm.Release {
    apiVersion: "helm.crossplane.io/v1beta1"
    kind: "Release"
    metadata: {
        name: "postgres-db"
    }
    spec: {
        providerConfigRef: { name: "default" }
        forProvider: {
            chart: {
                name: "postgresql"
                repository: "https://charts.bitnami.com/bitnami"
                version: "12.0.0"
            }
            namespace: "databases"
            values: {
                auth: {
                    postgresPassword: "changeme" # pragma: allowlist secret
                }
                primary: {
                    persistence: {
                        size: "10Gi"
                    }
                }
            }
        }
    }
}
```

```py
# Example 3: Crossplane v2 namespaced managed Release (helm.m.crossplane.io/v1beta1)
ns_release = helmm.Release {
    apiVersion: "helm.m.crossplane.io/v1beta1"
    kind: "Release"
    metadata: {
        name: "nginx-ns"
        namespace: "default"
    }
    spec: {
        providerConfigRef: {
            kind: "ClusterProviderConfig"
            name: "default"
        }
        forProvider: {
            chart: {
                name: "nginx"
                repository: "https://charts.bitnami.com/bitnami"
                version: "15.0.0"
            }
        }
    }
}
```
