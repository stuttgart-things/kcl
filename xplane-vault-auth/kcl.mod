[package]
name = "xplane-vault-auth"
version = "0.1.0"
description = "KCL module for Vault Kubernetes authentication using Terraform provider"
edition = "v0.11.0"

[dependencies]
crossplane-provider-terraform = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-terraform", tag = "0.1.0" }

[profile]
entries = ["main.k"]