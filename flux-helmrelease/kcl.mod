[package]
name = "flux-helmrelease"
edition = "v0.11.2"
version = "0.1.0"

[dependencies]
k8s = "1.31"
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }
