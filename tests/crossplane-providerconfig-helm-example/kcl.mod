[package]
name = "crossplane-providerconfig-helm-example"
edition = "v0.12.3"
version = "0.0.1"

[dependencies]
crossplane-providerconfig-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-providerconfig-helm", tag = "0.1.0" }
k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.28" }
