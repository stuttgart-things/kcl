[package]
name = "flux-infra-cert-manager-selfsigned"
edition = "v0.11.2"
version = "0.1.0"

[profile]
entries = ["main.k"]

[dependencies]
flux-kustomization = { oci = "oci://ghcr.io/stuttgart-things/flux-kustomization", tag = "0.1.0", version = "0.1.0" }
