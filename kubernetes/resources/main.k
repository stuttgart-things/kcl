"""
Kubernetes Resources Module

Standalone module for rendering basic Kubernetes resources (PVC, Secrets, ConfigMaps, etc).
Resources must be explicitly enabled via configuration (default: all disabled).

Uses official KCL k8s library (v1.32.4) for schema validation and type safety.

Usage with -D parameters:
  kcl run main.k \
    -D enablePvc=True \
    -D pvcName=my-pvc \
    -D pvcSize=50Gi \
    -D enableSecrets=True \
    -D secretName=my-secret

Usage with config file:
  kcl run main.k config.kcl

-D Parameters:
  # PVC Parameters
  enablePvc=True|False
  pvcName=<name>
  pvcNamespace=<namespace>
  pvcSize=<size>
  pvcStorageClass=<class>
  pvcVolumeMode=Filesystem|Block
  pvcAccessModes=<list>
  pvcLabels=<map>
  pvcAnnotations=<map>

  # Secret Parameters
  enableSecret=True|False
  secretName=<name>
  secretNamespace=<namespace>
  secretType=Opaque|<type>
  secretData=<map>
  secretLabels=<map>
  secretAnnotations=<map>

  # ConfigMap Parameters
  enableConfigMap=True|False
  configMapName=<name>
  configMapNamespace=<namespace>
  configMapData=<map>
  configMapLabels=<map>
  configMapAnnotations=<map>

  # Namespace Parameters
  enableNamespace=True|False
  namespaceName=<name>
  namespaceLabels=<map>
  namespaceAnnotations=<map>
"""

# === IMPORT K8S LIBRARY ===
import k8s.api.core.v1 as k8sv1

# === CONFIGURATION SCHEMAS ===

schema PvcConfig:
    enabled: bool = False
    name: str = "pvc"
    namespace: str = "default"
    size: str = "10Gi"
    storageClass: str = "standard"
    volumeMode: str = "Filesystem"
    accessModes: [str] = ["ReadWriteOnce"]
    labels: {str: str} = {}
    annotations: {str: str} = {}

schema SecretConfig:
    enabled: bool = False
    name: str = "secret"
    namespace: str = "default"
    type: str = "Opaque"
    data: {str: str} = {}
    labels: {str: str} = {}
    annotations: {str: str} = {}

schema ConfigMapConfig:
    enabled: bool = False
    name: str = "configmap"
    namespace: str = "default"
    data: {str: str} = {}
    binaryData: {str: str} = {}
    labels: {str: str} = {}
    annotations: {str: str} = {}

schema NamespaceConfig:
    enabled: bool = False
    name: str = "default"
    labels: {str: str} = {}
    annotations: {str: str} = {}

# === HELPER FUNCTIONS ===

# Parse comma-separated values into list
_parseList = lambda value: str -> [str] {
    ["ReadWriteOnce"] if not value else [part.strip() for part in value.strip("[").strip("]").split(",")]
}

# === ENABLE FLAGS WITH -D PARAMETER SUPPORT ===

# PVC Enable
_enablePvcValue = option("enablePvc")
_enablePvc = True if _enablePvcValue == True or _enablePvcValue == "true" else False

# Secret Enable  # pragma: allowlist secret
_enableSecretValue = option("enableSecret")
_enableSecret = True if _enableSecretValue == True or _enableSecretValue == "true" else False  # pragma: allowlist secret

# ConfigMap Enable
_enableConfigMapValue = option("enableConfigMap")
_enableConfigMap = True if _enableConfigMapValue == True or _enableConfigMapValue == "true" else False

# Namespace Enable
_enableNamespaceValue = option("enableNamespace")
_enableNamespace = True if _enableNamespaceValue == True or _enableNamespaceValue == "true" else False

# === PVC CONFIGURATION WITH -D PARAMETER SUPPORT ===

_pvcAccessModesStr = option("pvcAccessModes")
_pvc = PvcConfig {
    enabled = _enablePvc
    name = option("pvcName") or "pvc"
    namespace = option("pvcNamespace") or "default"
    size = option("pvcSize") or "10Gi"
    storageClass = option("pvcStorageClass") or "standard"
    volumeMode = option("pvcVolumeMode") or "Filesystem"
    accessModes = _parseList(_pvcAccessModesStr) if _pvcAccessModesStr else ["ReadWriteOnce"]
    labels = option("pvcLabels") or {}
    annotations = option("pvcAnnotations") or {}
}

# === SECRET CONFIGURATION WITH -D PARAMETER SUPPORT ===

_secret = SecretConfig {
    enabled = _enableSecret
    name = option("secretName") or "secret"
    namespace = option("secretNamespace") or "default"
    type = option("secretType") or "Opaque"
    data = option("secretData") or {}
    labels = option("secretLabels") or {}
    annotations = option("secretAnnotations") or {}
}

# === CONFIGMAP CONFIGURATION WITH -D PARAMETER SUPPORT ===

_configMap = ConfigMapConfig {
    enabled = _enableConfigMap
    name = option("configMapName") or "configmap"
    namespace = option("configMapNamespace") or "default"
    data = option("configMapData") or {}
    binaryData = option("configMapBinaryData") or {}
    labels = option("configMapLabels") or {}
    annotations = option("configMapAnnotations") or {}
}

# === NAMESPACE CONFIGURATION WITH -D PARAMETER SUPPORT ===

_namespace = NamespaceConfig {
    enabled = _enableNamespace
    name = option("namespaceName") or "default"
    labels = option("namespaceLabels") or {}
    annotations = option("namespaceAnnotations") or {}
}

# === RESOURCE GENERATORS ===

_generatePvc = lambda config: PvcConfig -> {str: any} {
    _metadata = {
        name = config.name
        namespace = config.namespace
    }

    _metadata = _addMetadataFields(_metadata, config.labels, config.annotations)

    {
        apiVersion = "v1"
        kind = "PersistentVolumeClaim"
        metadata = _metadata
        spec = {
            accessModes = config.accessModes
            resources = {
                requests = {
                    storage = config.size
                }
            }
            storageClassName = config.storageClass
            volumeMode = config.volumeMode
        }
    }
}

_addMetadataFields = lambda metadata: {str: any}, labels: {str: str}, annotations: {str: str} -> {str: any} {
    _m = metadata
    if labels:
        _m |= {labels = labels}
    if annotations:
        _m |= {annotations = annotations}
    _m
}

_generateSecret = lambda config: SecretConfig -> {str: any} {
    _metadata = {
        name = config.name
        namespace = config.namespace
    }

    _metadata = _addMetadataFields(_metadata, config.labels, config.annotations)

    {
        apiVersion = "v1"
        kind = "Secret"
        metadata = _metadata
        type = config.type
        data = config.data if config.data else {}
    }
}

_generateConfigMap = lambda config: ConfigMapConfig -> {str: any} {
    _metadata = {
        name = config.name
        namespace = config.namespace
    }

    _metadata = _addMetadataFields(_metadata, config.labels, config.annotations)

    _spec = {
        data = config.data if config.data else {}
    }

    if config.binaryData:
        _spec |= {binaryData = config.binaryData}

    {
        apiVersion = "v1"
        kind = "ConfigMap"
        metadata = _metadata
    } | _spec
}

_generateNamespace = lambda config: NamespaceConfig -> {str: any} {
    _metadata = {
        name = config.name
    }

    _metadata = _addMetadataFields(_metadata, config.labels, config.annotations)

    {
        apiVersion = "v1"
        kind = "Namespace"
        metadata = _metadata
    }
}

# === OUTPUT GENERATION ===

# Build items array with only enabled resources
# Order: Namespace -> PVC -> Secret -> ConfigMap
_namespaceItems = [_generateNamespace(_namespace)] if _namespace.enabled else []
_pvcItems = [_generatePvc(_pvc)] if _pvc.enabled else []
_secretItems = [_generateSecret(_secret)] if _secret.enabled else []
_configMapItems = [_generateConfigMap(_configMap)] if _configMap.enabled else []

# Combine all items in proper order
_allItems = _namespaceItems + _pvcItems + _secretItems + _configMapItems

# Export: Direct resource if single, list if multiple
_output = _allItems[0] if len(_allItems) == 1 else _allItems

# Flatten to root level if single resource, otherwise keep as list
_output
