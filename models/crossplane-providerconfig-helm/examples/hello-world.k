"""
Hello World Example for Crossplane Helm ProviderConfig

This example demonstrates how to create a basic Helm ProviderConfig
that connects to a Kubernetes cluster using a kubeconfig secret reference.
"""

import k8s.apimachinery.pkg.apis.meta.v1
import ..v1beta1 as v1beta1

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
