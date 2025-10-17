[package]
name = "xplane-vcluster"
version = "0.0.1"

[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }
crossplane-provider-kubernetes = "0.18.0"
