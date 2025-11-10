[package]
name = "xplane-vault-config"
edition = "v0.11.2"
version = "0.3.5"

[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }
crossplane-provider-kubernetes = "0.18.0"
