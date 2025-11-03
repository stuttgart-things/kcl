[package]
name = "xplane-vcluster"
version = "0.29.2"

[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }
crossplane-provider-kubernetes = "0.18.0"
