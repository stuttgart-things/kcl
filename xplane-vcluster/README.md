# Crossplane VCluster KCL Module

This KCL module creates Crossplane resources for Tinkerbell workflows and optionally Helm releases through Crossplane.

## Features

- **Tinkerbell Workflow**: Creates workflows for bare-metal provisioning
- **Helm Release**: Optionally creates Helm releases with OCI registry support
- **Flexible Configuration**: Supports various chart repositories and values

## Usage

### Basic Workflow Only

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "simple-workflow",
      "targetNamespace": "tinkerbell-system",
      "templateRef": "ubuntu-template",
      "hardwareRef": "worker-01",
      "macAddr": "aa:bb:cc:dd:ee:ff",
      "cluster": "production-cluster",
      "enableHelmRelease": false,
      "printItems": true
    }
  }
}'
```

### Workflow with Helm Release

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "example-workflow",
      "targetNamespace": "tinkerbell-system",
      "templateRef": "ubuntu-provisioning",
      "hardwareRef": "worker-node-01",
      "macAddr": "aa:bb:cc:dd:ee:ff",
      "cluster": "production-cluster",
      "enableHelmRelease": true,
      "helmRelease": {
        "name": "wordpress-example",
        "chart": {
          "name": "wordpress",
          "repository": "oci://registry.local:5000/helm-charts",
          "version": "15.2.5"
        },
        "namespace": "wordpress",
        "insecureSkipTLSVerify": true,
        "skipCRDs": true,
        "values": {
          "service": {
            "type": "LoadBalancer"
          },
          "persistence": {
            "enabled": true,
            "size": "10Gi"
          }
        },
        "set": [
          {
            "name": "wordpressUsername",
            "value": "admin"
          }
        ],
        "providerConfig": "helm-provider-config"
      },
      "printItems": true
    }
  }
}'
```

## Parameters

### Workflow Parameters
- `name`: Name of the workflow/release
- `targetNamespace`: Target namespace for Tinkerbell workflow
- `templateRef`: Reference to Tinkerbell template
- `hardwareRef`: Reference to hardware definition
- `macAddr`: MAC address for hardware mapping
- `cluster`: Crossplane provider config reference

### Helm Release Parameters (optional)
- `enableHelmRelease`: Boolean flag to enable Helm release creation
- `helmRelease.name`: Name of the Helm release
- `helmRelease.chart.name`: Chart name
- `helmRelease.chart.repository`: Chart repository (supports OCI)
- `helmRelease.chart.version`: Chart version
- `helmRelease.namespace`: Target namespace for Helm release
- `helmRelease.insecureSkipTLSVerify`: Skip TLS verification
- `helmRelease.skipCRDs`: Skip CRD installation
- `helmRelease.values`: Helm values as object
- `helmRelease.set`: Array of key-value pairs to set
- `helmRelease.providerConfig`: Helm provider config reference

### Control Parameters
- `printItems`: Boolean flag to control output (default: true)

## Output

Creates one or both of:
1. `kubernetes.crossplane.io/v1alpha2/Object` wrapping a `tinkerbell.org/v1alpha1/Workflow`
2. `kubernetes.crossplane.io/v1alpha2/Object` wrapping a `helm.crossplane.io/v1beta1/Release`

Based on the example from: https://raw.githubusercontent.com/crossplane-contrib/provider-helm/refs/heads/main/examples/cluster/sample/release-oci.yaml
