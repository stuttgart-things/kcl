[package]
name = "flux-kustomization"
edition = "v0.11.2"
version = "0.1.1"

[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.5" }
k8s = "1.36"
