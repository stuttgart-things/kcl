# XPlane Vault Cluster Configuration

KCL module for generating Vault cluster configuration using Terraform Workspace pattern.

## Features

- Crossplane-compliant variable access pattern
- Terraform Workspace integration with stuttgart-things/vault-base-setup
- JSON-formatted variable passing
- Kubernetes Secret generation for Terraform variables

## Usage

### Basic Test with Crossplane XR Structure

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "vault-dev-cluster",
      "namespace": "vault-system",
      "vaultAddr": "https://vault.demo-infra.example.com",
      "clusterName": "kind-dev2",
      "context": "kind-dev2",
      "kubeconfigPath": "/home/user/.kube/kind-dev2"
    }
  }
}'
```

### Test with Minimal Parameters (uses defaults)

```bash
kcl run main.k -D params='{"oxr":{"spec":{"name":"test-vault"}}}'
```

### Test with Empty Parameters (all defaults)

```bash
kcl run main.k -D params='{}'
```

## Variable Pattern

Following Container-Use specifications for Crossplane-compliant variable access:

```kcl
name = option("params")?.oxr?.spec?.name or "vault-cluster"
```

## Generated Resources

1. **Kubernetes Secret**: Contains Terraform variables in JSON format
2. **Terraform Workspace**: References the vault-base-setup module

## Generated Terraform Variables

The module generates a JSON-formatted `terraform.tfvars.json` file containing:

```json
{
  "vault_addr": "https://vault.demo-infra.example.com",
  "cluster_name": "kind-dev2", 
  "context": "kind-dev2",
  "skip_tls_verify": true,
  "kubeconfig_path": "/home/sthings/.kube/kind-dev2",
  "csi_enabled": true,
  "namespace_csi": "vault",
  "vso_enabled": true,
  "namespace_vso": "vault",
  "k8s_auths": [
    {
      "name": "dev",
      "namespace": "default",
      "token_policies": ["read-k8s", "write-secrets"],
      "token_ttl": 7200
    },
    {
      "name": "prod", 
      "namespace": "production",
      "token_policies": ["read-only"],
      "token_ttl": 3600
    }
  ]
}
```

### Variable Defaults

- `vault_addr`: "https://vault.example.com"
- `cluster_name`: "dev-cluster"
- `context`: "default"
- `skip_tls_verify`: true
- `kubeconfig_path`: "/home/user/.kube/config"
- `csi_enabled`: true
- `namespace_csi`: "vault"
- `vso_enabled`: true
- `namespace_vso`: "vault"
- `k8s_auths`: Default single auth for "dev" namespace

This JSON format is compatible with the [stuttgart-things/vault-base-setup](https://github.com/stuttgart-things/vault-base-setup) Terraform module variables.

## Dependencies

- JSON package for variable encoding
- Crossplane Terraform Provider
- stuttgart-things/vault-base-setup module