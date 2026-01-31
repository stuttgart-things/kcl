"""
OpenEBS StoragePlatform Template

Generates a Crossplane StoragePlatform claim for deploying OpenEBS
with configurable storage engines (LVM, ZFS, Mayastor).

Usage:
    kcl run templates/openebs.k -D enableLvm=true
    kcl run templates/openebs.k -D name=openebs-mayastor -D enableMayastor=true -D enableVolumeSnapshots=true
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_storage_platform as sp

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.sp?.spec or {}

# Common parameters
_name = _spec?.name or option("name") or "openebs-local"
_namespace = _spec?.namespace or option("namespace") or "default"
_targetClusterName = _spec?.targetClusterName or option("targetClusterName") or "in-cluster"
_targetClusterScope = _spec?.targetClusterScope or option("targetClusterScope") or "Cluster"

# OpenEBS parameters
_openebsVersion = _spec?.openebsVersion or option("openebsVersion") or "4.2.0"
_openebsNamespace = _spec?.openebsNamespace or option("openebsNamespace") or "openebs-system"
_enableLvm = _spec?.enableLvm or option("enableLvm") or False
_enableZfs = _spec?.enableZfs or option("enableZfs") or False
_enableMayastor = _spec?.enableMayastor or option("enableMayastor") or False
_enableVolumeSnapshots = _spec?.enableVolumeSnapshots or option("enableVolumeSnapshots") or False
_enableCsiNodeInitContainers = _spec?.enableCsiNodeInitContainers or option("enableCsiNodeInitContainers") or False

# OpenEBS StoragePlatform
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
