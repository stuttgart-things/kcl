# stuttgart-things/kcl/xplane-base

## RENDER PROVIDER CONFIG ONLY

```bash
kcl run --quiet main.k -D 'params={
    "oxr": {
      "spec": {
        "name": "prod",
        "enableHelmProvider": {
          "enabled": true,
          "secretKey": "kubeconfig"
        },
        "enableKubernetesProvider": {
          "enabled": true,
          "secretKey": "kubeconfig"
        },
        "connectionSecret": {
          "namespace": "crossplane-system",
          "name": "cluster-connection"
        }
      }
    }
  }' --format yaml | grep -A 1000 "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```

## RENDER PROVIDER + VAULT STATIC SECRET

```bash
kcl run --quiet main.k -D 'params={
    "oxr": {
      "spec": {
        "name": "prod",
        "enableVaultSecret": {
          "enabled": true,
          "name": "kind-demo",
          "namespace": "default",
          "mount": "kubeconfigs",
          "path": "kv/demo-infra",
          "authRef": "dev",
          "refreshAfter": "10s",
          "destinationSecretName": "kind-demo"
        },
        "enableHelmProvider": {
          "enabled": true
        },
        "enableKubernetesProvider": {
          "enabled": true
        },
        "connectionSecret": {
          "namespace": "crossplane-system",
          "name": "kind-demo"
        }
      }
    }
  }' --format yaml | grep -A 1000 "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```
