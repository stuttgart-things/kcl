import schema

# Enable/disable PVC creation (can be overridden via -D)
_enablePvcValue = option("enablePvc")
_enablePvcBool = True if _enablePvcValue == True or _enablePvcValue == "true" or _enablePvcValue == None else False

# Configuration with defaults that can be overridden via -D
_config = schema.PersistentVolumeClaimConfig {
    name = option("name") or "dev2-disk-0"
    namespace = option("namespace") or "default"
    imageNamespace = option("imageNamespace") or "default"
    imageId = option("imageId") or "image-t9w92"
    storage = option("storage") or "10Gi"
    storageClass = option("storageClass") or "longhorn"
    volumeMode = option("volumeMode") or "Block"
    accessModes = option("accessModes") or ["ReadWriteMany"]
}

# Construct full image ID and storage class name
_fullImageId = "${_config.imageNamespace}/${_config.imageId}"
_fullStorageClassName = "${_config.storageClass}-${_config.imageId}"

# Define the PVC resource
_pvc = {
    apiVersion = "v1"
    kind = "PersistentVolumeClaim"
    metadata = {
        name = _config.name
        namespace = _config.namespace
        annotations = {
            "harvesterhci.io/imageId" = _fullImageId
        }
    }
    spec = {
        accessModes = _config.accessModes
        resources = {
            requests = {
                storage = _config.storage
            }
        }
        storageClassName = _fullStorageClassName
        volumeMode = _config.volumeMode
    }
}

# Generate items conditionally
items = [_pvc] if _enablePvcBool else []
