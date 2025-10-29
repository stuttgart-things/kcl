[package]
name = "kcl-flux-tekton"
edition = "v0.11.2"
version = "0.1.0"

description = "KCL module for Tekton deployment via Flux using Helm/Kustomize and Kubernetes resources."

[dependencies]
k8s = "1.31"
flux-helmrelease = { oci = "oci://ghcr.io/stuttgart-things/flux-helmrelease", tag = "0.1.0" }
flux-kustomization = { oci = "oci://ghcr.io/stuttgart-things/flux-kustomization", tag = "0.1.0" }
