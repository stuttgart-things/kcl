[package]
name = "xplane-vault-auth-base"
version = "0.4.0"
description = "KCL module for creating Vault Kubernetes authentication backends using Crossplane and Terraform provider with count-based approach"
edition = "v0.11.0"

[dependencies]
crossplane-provider-terraform = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-terraform", tag = "0.1.0" }

[profile]
entries = ["main.k"]
