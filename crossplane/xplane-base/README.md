

## RENDER

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