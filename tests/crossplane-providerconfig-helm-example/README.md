# crossplane-providerconfig-helm-example

Minimal example of consuming the published
`ghcr.io/stuttgart-things/crossplane-providerconfig-helm` package: it builds one
Crossplane Helm `ProviderConfig` that reads its kubeconfig from a Secret.

Not published — this is a usage example, exercised by CI like any other module.

## Run

```bash
kcl run .
```

```yaml
helloWorldProviderConfig:
  apiVersion: helm.m.crossplane.io/v1beta1
  kind: ProviderConfig
  metadata:
    name: hello-world-helm
    namespace: crossplane-system
  spec:
    credentials:
      secretRef:
        key: kubeconfig
        name: kubeconfig-secret
        namespace: crossplane-system
      source: Secret
```

## Why `kcl.mod` declares no `k8s` dependency

`crossplane-providerconfig-helm@0.1.0` ships its own vendored copy of
`k8s.apimachinery` inside the package. Declaring `k8s` here as well makes kcl see
the same package twice and the module stops compiling:

```
the `k8s.apimachinery.pkg.apis.meta.v1` is found multiple times in the
current package and vendor package
```

So the dependency list deliberately holds only the provider config package. If a
future version of it stops vendoring `k8s`, this will need adding back.
