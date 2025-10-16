[package]
name = "my-helm-deployments"
description = "My Helm releases using Crossplane"
version = "0.0.1"

[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }