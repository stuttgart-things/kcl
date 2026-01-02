"""
Hello World Example for Crossplane Helm ProviderConfig using OCI Dependency

This example demonstrates how to create a basic Helm ProviderConfig
by importing from the published OCI package at:
ghcr.io/stuttgart-things/crossplane-providerconfig-helm:0.1.0

This package contains the schema definitions for Crossplane Helm ProviderConfig.
"""

import crossplane_providerconfig_helm.v1beta1 as v1beta1

# Create a simple Helm ProviderConfig using secret-based credentials
helloWorldProviderConfig: v1beta1.ProviderConfig = {
    metadata = {
        name = "hello-world-helm"
        namespace = "crossplane-system"
    }
    spec = {
        # Use Secret source to reference kubeconfig credentials
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = "crossplane-system"
                name = "kubeconfig-secret"
                key = "kubeconfig"
            }
        }
    }
}
