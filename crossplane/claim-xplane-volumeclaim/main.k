"""
Example usage of VolumeClaim resource from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name or boolean flag.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_volume_claim as vc

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.vc?.spec or {}

# Template selector - can use either templateName or useDbTemplate
_templateName = option("templateName") or _params?.templateName or "demo"  # Options: "demo", "database", or "simple"
_useDbTemplate = option("useDbTemplate") or _params?.useDbTemplate or False  # Boolean alternative

# Common parameters
_name = _spec?.pvcName or option("pvcName") or "demo-pvc"
_namespace = _spec?.namespace or option("namespace") or _params?.namespace or "default"
_claimNamespace = _spec?.claimNamespace or option("claimNamespace") or _params?.claimNamespace or _namespace
_storage = _spec?.storage or option("storage") or "20Gi"
_storageClass = _spec?.storageClassName or option("storageClassName") or "standard"
_accessModes = _spec?.accessModes or option("accessModes") or ["ReadWriteOnce"]
_volumeMode = _spec?.volumeMode or option("volumeMode") or "Filesystem"
_providerConfig = _spec?.providerConfigRef or option("providerConfig") or "default-k8s"

# Determine which template to use (boolean takes precedence if set explicitly)
_selectedTemplate = "database" if _useDbTemplate else _templateName

# Valid template options: "demo", "database", "simple"

# Demo/Default Template
if _selectedTemplate == "demo":
    vc.VolumeClaim {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _claimNamespace
            annotations = {
                "example.com/managed-by": "kcl-test"
            }
        }

        spec = vc.ResourcesStuttgartThingsComV1alpha1VolumeClaimSpec {
            pvcName = _name
            namespace = _namespace
            storage = _storage
            storageClassName = _storageClass
            accessModes = _accessModes
            volumeMode = _volumeMode
            providerConfigRef = _providerConfig
        }
    }

# Database Template
if _selectedTemplate == "database":
    vc.VolumeClaim {
        metadata = v1.ObjectMeta {
            name = "db-pvc"
            namespace = _claimNamespace
            annotations = {
                "example.com/managed-by": "kcl-test",
                "backup.velero.io/backup-volumes": "db-data"
            }
            labels = {
                "app": "database",
                "tier": "backend",
                "environment": "production"
            }
        }

        spec = vc.ResourcesStuttgartThingsComV1alpha1VolumeClaimSpec {
            pvcName = "db-pvc"
            namespace = _namespace
            storage = "100Gi"
            storageClassName = "fast-ssd"
            accessModes = ["ReadWriteOnce"]
            volumeMode = "Filesystem"
            providerConfigRef = _providerConfig
            labels = {
                "app": "database",
                "tier": "backend",
                "environment": "production"
            }
            # Example with selector for pre-provisioned PV
            selector = vc.ResourcesStuttgartThingsComV1alpha1VolumeClaimSpecSelector {
                matchLabels = {
                    "type": "fast-ssd",
                    "zone": "us-west-2a"
                }
            }
        }
    }

# Simple Template
if _selectedTemplate == "simple":
    vc.VolumeClaim {
        metadata = v1.ObjectMeta {
            name = option("simpleName") or "simple-storage"
            namespace = _claimNamespace
        }

        spec = vc.ResourcesStuttgartThingsComV1alpha1VolumeClaimSpec {
            providerConfigRef = option("providerConfig") or _providerConfig or "in-cluster"
            annotations = {
                "description": option("description") or "A simple persistent volume claim for application data"
            }
            pvcName = option("pvcName") or "app-data"
            namespace = _namespace
            storageClassName = _storageClass
            storage = _storage
        }
    }
