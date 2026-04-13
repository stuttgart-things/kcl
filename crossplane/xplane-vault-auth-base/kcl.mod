[package]
name = "xplane-vault-auth-base"
edition = "v0.11.0"
version = "0.5.0"
description = "KCL library for creating Vault Kubernetes authentication backends as Crossplane v2 namespaced OpenTofu Workspaces"

[dependencies]
crossplane-provider-opentofu = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-opentofu", tag = "0.1.0" }

[profile]
entries = ["main.k"]
