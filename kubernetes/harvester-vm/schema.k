schema PersistentVolumeClaimConfig:
    """
    PersistentVolumeClaim configuration schema for Harvester HCI image-backed volumes

    Args:
        name: str, required - Name of the PVC
        namespace: str, default "default" - Namespace for the PVC
        imageNamespace: str, default "default" - Namespace of the Harvester image
        imageId: str, required - Harvester image ID (e.g., "image-t9w92")
        storage: str, default "10Gi" - Storage size request
        accessModes: [str], default ["ReadWriteMany"] - Access modes for the volume
        storageClass: str, required - Storage class base name (e.g., "longhorn")
        volumeMode: str, default "Block" - Volume mode (Block or Filesystem)
    """
    name: str
    namespace: str = "default"
    imageNamespace: str = "default"
    imageId: str
    storage: str = "10Gi"
    accessModes: [str] = ["ReadWriteMany"]
    storageClass: str
    volumeMode: str = "Block"

    check:
        len(name) > 0, "name cannot be empty"
        len(imageId) > 0, "imageId cannot be empty"
        len(storageClass) > 0, "storageClass cannot be empty"
        volumeMode in ["Block", "Filesystem"], "volumeMode must be Block or Filesystem"
