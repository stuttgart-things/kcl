"""
KCL Module for Tekton Deployment via Flux
Generates Kubernetes resources for deploying Tekton Pipelines using Flux CD with Helm.

This module provides:
- Namespace configuration with tenant labels
- HelmRepository for OCI-based chart repositories
- HelmRelease for Tekton deployment
"""

import k8s.api.core.v1 as corev1
import flux_helmrelease.v2.helm_toolkit_fluxcd_io_v2_helm_release as fluxhelm

schema TektonConfig:
    """
    Configuration schema for Tekton deployment via Flux.

    Attributes:
        name: Name of the HelmRelease and Tekton installation
        namespace: Kubernetes namespace for Tekton installation
        version: Tekton chart version to deploy
        tenant: Tenant label for Flux multi-tenancy
        chartRepo: OCI repository URL for Tekton Helm chart
        repoName: Name of the HelmRepository resource
        interval: Sync interval for HelmRelease (default: "30m")
        repoInterval: Sync interval for HelmRepository (default: "1h")
    """
    name: str = "tekton-pipelines"
    namespace: str = "tekton-pipelines"
    version: str = "0.76.1"
    tenant: str = "sthings-team"
    chartRepo: str = "oci://ghcr.io/stuttgart-things/tekton"
    repoName: str = "stuttgart-things"
    interval: str = "30m"
    repoInterval: str = "1h"

    check:
        len(name) > 0, "name cannot be empty"
        len(namespace) > 0, "namespace cannot be empty"
        len(version) > 0, "version cannot be empty"

def makeNamespace(cfg: TektonConfig) -> corev1.Namespace:
    """
    Creates a Kubernetes Namespace with Flux tenant labels.

    Args:
        cfg: TektonConfig with namespace and tenant settings

    Returns:
        Kubernetes Namespace resource
    """
    corev1.Namespace {
        metadata = {
            name = cfg.namespace
            labels = {
                "toolkit.fluxcd.io/tenant" = cfg.tenant
            }
        }
    }

def makeHelmRepository(cfg: TektonConfig) -> any:
    """
    Creates a Flux HelmRepository resource for OCI registries.

    Args:
        cfg: TektonConfig with chart repository settings

    Returns:
        Flux HelmRepository resource
    """
    {
        apiVersion = "source.toolkit.fluxcd.io/v1beta2"
        kind = "HelmRepository"
        metadata = {
            name = cfg.repoName
            namespace = cfg.namespace
        }
        spec = {
            type = "oci"
            interval = cfg.repoInterval
            url = cfg.chartRepo
        }
    }

def makeHelmRelease(cfg: TektonConfig) -> fluxhelm.HelmRelease:
    """
    Creates a Flux HelmRelease for Tekton deployment.

    Args:
        cfg: TektonConfig with deployment settings

    Returns:
        Flux HelmRelease resource
    """
    fluxhelm.HelmRelease {
        metadata = {
            name = cfg.name
            namespace = cfg.namespace
        }
        spec = {
            interval = cfg.interval
            chart = {
                spec = {
                    chart = "tekton"
                    version = cfg.version
                    sourceRef = {
                        kind = "HelmRepository"
                        name = cfg.repoName
                        namespace = cfg.namespace
                    }
                }
            }
        }
    }

def tektonResources(cfg: TektonConfig) -> [any]:
    """
    Generates all Kubernetes resources for Tekton deployment.

    Args:
        cfg: TektonConfig with deployment settings

    Returns:
        List containing Namespace, HelmRepository, and HelmRelease resources
    """
    [
        makeNamespace(cfg),
        makeHelmRepository(cfg),
        makeHelmRelease(cfg)
    ]
