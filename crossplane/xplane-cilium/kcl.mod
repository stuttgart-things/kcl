[package]
name = "xplane-cilium"
edition = "v0.11.2"
version = "1.19.1"

[dependencies]
crossplane-provider-kubernetes = "0.18.0"
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.4" }
