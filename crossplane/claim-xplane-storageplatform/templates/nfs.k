"""
NFS StoragePlatform Template

Generates a Crossplane StoragePlatform claim for deploying NFS CSI driver
with StorageClass configuration.

Usage:
    kcl run templates/nfs.k -D serverFQDN=nfs.example.com -D sharePath=/exports/k8s
    kcl run templates/nfs.k -D name=my-nfs -D serverFQDN=10.0.0.1 -D sharePath=/data -D storageClass=nfs-storage
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_storage_platform as sp

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.sp?.spec or {}

# Common parameters
_name = _spec?.name or option("name") or "nfs-storage"
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

# Helper: parse mount options
_mountOptions = [opt for opt in _mountOptionsStr.split(",") if opt] if _mountOptionsStr else []

# NFS StoragePlatform
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
