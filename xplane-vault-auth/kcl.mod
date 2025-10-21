[package]
name = "xplane-vault-auth"
edition = "v0.10.0"
version = "0.1.0"
description = "KCL module for Vault authentication setup using Terraform provider via Crossplane"
authors = ["Stuttgart-Things"]

[dependencies]
k8s = "1.32.4"
# TODO: Switch to OCI when crossplane-provider-terraform is published
# crossplane-provider-terraform = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-terraform", tag = "0.1.0" }