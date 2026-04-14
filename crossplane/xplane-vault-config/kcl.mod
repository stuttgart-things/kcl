[package]
name = "xplane-vault-config"
edition = "v0.11.2"
version = "0.5.0"

[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.4" }
crossplane-provider-kubernetes = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-kubernetes", tag = "0.1.1" }
