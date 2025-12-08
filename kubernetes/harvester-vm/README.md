# HARVESTER-VM

## PVC

```bash
kcl run main.k \
  -D enablePvc=true \
  -D name=dev2-disk-0 \
  -D namespace=default \
  -D imageNamespace=default \
  -D imageId=image-t9w92 \
  -D storage=10Gi \
  -D storageClass=longhorn \
  -D volumeMode=Block \
  -D 'accessModes=["ReadWriteMany"]'
```
