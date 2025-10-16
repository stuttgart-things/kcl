# Crossplane Helm Release KCL Module

This KCL module creates a Crossplane Kubernetes Object resource for deploying Helm charts through Crossplane using the Kubernetes provider.

## Usage

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "nginx-ingress",
      "namespace": "ingress-nginx",
      "chart": "ingress-nginx",
      "repository": "https://kubernetes.github.io/ingress-nginx",
      "version": "4.8.3",
      "cluster": "production-cluster",
      "values": {
        "controller": {
          "service": {
            "type": "LoadBalancer"
          }
        }
      },
      "printItems": true
    }
  }
}'
```

## Parameters

- `name`: Name of the Helm release
- `namespace`: Target namespace for the release (default: "default")
- `chart`: Name of the Helm chart
- `repository`: Helm chart repository URL
- `version`: Chart version to deploy
- `cluster`: Crossplane provider config reference
- `values`: Helm values as a map/object
- `printItems`: Boolean flag to control output (default: true)

## Output

Creates a `kubernetes.crossplane.io/v1alpha2/Object` resource that wraps a `helm.cattle.io/v1/HelmChart` resource for deployment through Crossplane with the Kubernetes provider.