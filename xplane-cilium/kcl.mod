[package]
name = "xplane-cilium"
description = "My Helm releases using Crossplane"
version = "1.19.0"

[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }
