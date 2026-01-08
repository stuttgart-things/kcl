# CLAIM-XPLANE-VOLUMECLAIM

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-volumeclaim --tag 0.1.1 -D templateName=simple -D namespace=production -D storage=10Gi  -D storageClassName=bla
```

```bash
# Or explicitly specify demo
kcl run volume-claim.k -D templateName=demo
```

```bash
# Load database template
kcl run volume-claim.k -D templateName=database
```
