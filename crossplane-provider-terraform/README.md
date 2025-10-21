# Crossplane Provider Terraform KCL Module

KCL module for Crossplane Terraform Provider resources, generated from CRDs.

## Features

- **Generated KCL Schemas**: Auto-generated from Terraform Provider CRDs
- **Type Safety**: Full KCL type checking for Terraform resources
- **Crossplane Integration**: Native support for Crossplane composition patterns
- **Stuttgart-Things Standards**: Follows organizational conventions

## Generated Resources

- **Workspace**: Terraform workspace management via Crossplane

## Usage

```kcl
import tf

# Create a Terraform workspace
workspace = tf.v1beta1.Workspace {
    apiVersion = "tf.upbound.io/v1beta1"
    kind = "Workspace"
    metadata.name = "my-terraform-workspace"
    spec = {
        # Workspace configuration
    }
}
```

## Installation

```bash
# Import in your KCL project
import crossplane_provider_terraform as tf
```

## Development

This module was generated using:

```bash
kcl import -m crd https://raw.githubusercontent.com/crossplane-contrib/provider-terraform/a3d2e01283e3c1b78eaaaf961fcabba5345a595f/package/crds/tf.upbound.io_workspaces.yaml
```

## Testing

```bash
# Test the module
kcl run main.k
```