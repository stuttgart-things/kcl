"""
StoragePlatform KCL Module - Entry Point

This module provides templates for generating Crossplane StoragePlatform claims
to provision storage backends (NFS or OpenEBS) on Kubernetes clusters.

Templates:
- nfs: NFS CSI driver with StorageClass configuration
- openebs: OpenEBS storage platform with configurable engines

Usage via main.k:
    kcl run . -D templateName=nfs -D serverFQDN=nfs.example.com -D sharePath=/exports/k8s
    kcl run . -D templateName=openebs -D enableLvm=true

Usage via standalone templates:
    kcl run templates/nfs.k -D serverFQDN=nfs.example.com -D sharePath=/exports/k8s
    kcl run templates/openebs.k -D enableLvm=true
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_storage_platform as sp

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.sp?.spec or {}

# Template selector
_templateName = option("templateName") or _params?.templateName or "nfs"

# Common parameters
_name = _spec?.name or option("name") or "storage-platform"
_namespace = _spec?.namespace or option("namespace") or "default"
_targetClusterName = _spec?.targetClusterName or option("targetClusterName") or "in-cluster"
_targetClusterScope = _spec?.targetClusterScope or option("targetClusterScope") or "Cluster"

# NFS parameters
_serverFQDN = _spec?.serverFQDN or option("serverFQDN") or ""
_sharePath = _spec?.sharePath or option("sharePath") or ""
_storageClass = _spec?.storageClass or option("storageClass") or "nfs-client"
_nfsVersion = _spec?.nfsVersion or option("nfsVersion") or "v4.11.0"
_nfsNamespace = _spec?.nfsNamespace or option("nfsNamespace") or "kube-system"
_reclaimPolicy = _spec?.reclaimPolicy or option("reclaimPolicy") or "Delete"
_volumeBindingMode = _spec?.volumeBindingMode or option("volumeBindingMode") or "Immediate"
_mountOptionsStr = _spec?.mountOptions or option("mountOptions") or ""

# OpenEBS parameters
_openebsVersion = _spec?.openebsVersion or option("openebsVersion") or "4.2.0"
_openebsNamespace = _spec?.openebsNamespace or option("openebsNamespace") or "openebs-system"
_enableLvm = _spec?.enableLvm or option("enableLvm") or False
_enableZfs = _spec?.enableZfs or option("enableZfs") or False
_enableMayastor = _spec?.enableMayastor or option("enableMayastor") or False
_enableVolumeSnapshots = _spec?.enableVolumeSnapshots or option("enableVolumeSnapshots") or False
_enableCsiNodeInitContainers = _spec?.enableCsiNodeInitContainers or option("enableCsiNodeInitContainers") or False

# Helper: parse mount options
_mountOptions = [opt for opt in _mountOptionsStr.split(",") if opt] if _mountOptionsStr else []

# Template: NFS
if _templateName == "nfs":
    sp.StoragePlatform {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-storageplatform"
                "storage-type": "nfs"
            }
            labels = {
                "app.kubernetes.io/managed-by": "crossplane"
                "storage.stuttgart-things.com/type": "nfs"
            }
        }
        spec = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpec {
            engine = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecEngine {
                type = "nfs"
            }
            targetCluster = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecTargetCluster {
                name = _targetClusterName
                scope = _targetClusterScope
            }
            nfs = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecNfs {
                namespace = _nfsNamespace
                version = _nfsVersion
                serverFQDN = _serverFQDN
                sharePath = _sharePath
                storageClass = _storageClass
                reclaimPolicy = _reclaimPolicy
                volumeBindingMode = _volumeBindingMode
                if _mountOptions:
                    mountOptions = _mountOptions
            }
        }
    }

# Template: OpenEBS
if _templateName == "openebs":
    sp.StoragePlatform {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "managed-by": "kcl-storageplatform"
                "storage-type": "openebs"
            }
            labels = {
                "app.kubernetes.io/managed-by": "crossplane"
                "storage.stuttgart-things.com/type": "openebs"
            }
        }
        spec = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpec {
            engine = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecEngine {
                type = "openebs"
            }
            targetCluster = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecTargetCluster {
                name = _targetClusterName
                scope = _targetClusterScope
            }
            openebs = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecOpenebs {
                namespace = _openebsNamespace
                version = _openebsVersion
                features = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecOpenebsFeatures {
                    volumeSnapshots = _enableVolumeSnapshots
                    csiNodeInitContainers = _enableCsiNodeInitContainers
                }
                engines = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecOpenebsEngines {
                    local = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecOpenebsEnginesLocal {
                        lvm = _enableLvm
                        zfs = _enableZfs
                    }
                    replicated = sp.ResourcesStuttgartThingsComV1alpha1StoragePlatformSpecOpenebsEnginesReplicated {
                        mayastor = _enableMayastor
                    }
                }
            }
        }
    }
