import schema

# Enable/disable resources (can be overridden via -D)
_enablePvcValue = option("enablePvc")
_enablePvcBool = True if _enablePvcValue == True or _enablePvcValue == "true" or _enablePvcValue == None else False

_enableCloudConfigValue = option("enableCloudConfig")
_enableCloudConfigBool = True if _enableCloudConfigValue == True or _enableCloudConfigValue == "true" or _enableCloudConfigValue == None else False

# PVC Configuration with defaults that can be overridden via -D
_pvcConfig = schema.PersistentVolumeClaimConfig {
    name = option("pvcName") or "dev2-disk-0"
    namespace = option("namespace") or "default"
    imageNamespace = option("imageNamespace") or "default"
    imageId = option("imageId") or "image-t9w92"
    storage = option("storage") or "10Gi"
    storageClass = option("storageClass") or "longhorn"
    volumeMode = option("volumeMode") or "Block"
    accessModes = option("accessModes") or ["ReadWriteMany"]
}

# Cloud Config Secret Configuration
_secretConfig = schema.CloudConfigSecretConfig {
    name = option("secretName") or "dev4"
    namespace = option("namespace") or "default"
    userdata = option("userdata") or ""
    networkdata = option("networkdata") or ""
}

# Define the PVC resource
_pvc = {
    apiVersion = "v1"
    kind = "PersistentVolumeClaim"
    metadata = {
        name = _pvcConfig.name
        namespace = _pvcConfig.namespace
        annotations = {
            "harvesterhci.io/imageId" = "${_pvcConfig.imageNamespace}/${_pvcConfig.imageId}"
        }
    }
    spec = {
        accessModes = _pvcConfig.accessModes
        resources = {
            requests = {
                storage = _pvcConfig.storage
            }
        }
        storageClassName = "${_pvcConfig.storageClass}-${_pvcConfig.imageId}"
        volumeMode = _pvcConfig.volumeMode
    }
}

# Define the Cloud Config Secret resource
_secret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = _secretConfig.name
        namespace = _secretConfig.namespace
    }
    type = "secret"
    data = {
        userdata = _secretConfig.userdata
        networkdata = _secretConfig.networkdata
    }
}

# Generate items conditionally
_pvcResources = [_pvc] if _enablePvcBool else []
_secretResources = [_secret] if _enableCloudConfigBool else []
items = _pvcResources + _secretResources
