# CRD Sources

This file tracks the Custom Resource Definitions (CRDs) used in this module and their conversion details.

## Flux Helm Controller

### Source Information
- **Upstream Repository**: [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator)
- **CRD URL**: https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/helm-controller.yaml
- **Flux Version**: v2.7.2
- **Commit SHA**: d78658085afc5e2de06358f35f05ef317de6a25d
- **Conversion Date**: 2025-10-23
- **Converted By**: stuttgart-things/dagger KCL module

### CRD Details
- **API Group**: helm.toolkit.fluxcd.io
- **Kinds**: HelmRelease
- **API Versions**: 
  - v2 (primary, 1504 lines)
  - v2beta2 (compatibility, 1510 lines)

### Conversion Command
```bash
dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
  --crd-source "https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/helm-controller.yaml" \
  --progress plain \
  export --path=./generated-models
```

### Generated Files
- `v2/helm_toolkit_fluxcd_io_v2_helm_release.k`
- `v2beta2/helm_toolkit_fluxcd_io_v2beta2_helm_release.k`
- K8s metadata types (via k8s:1.31 dependency)

### Update Instructions

When Flux releases a new version:

1. **Update CRD URL** with new version:
   ```bash
   FLUX_VERSION="v2.8.0"  # Update to new version
   CRD_URL="https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/main/config/data/flux/${FLUX_VERSION}/helm-controller.yaml"
   ```

2. **Re-convert using Dagger**:
   ```bash
   dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
     --crd-source "${CRD_URL}" \
     --progress plain \
     export --path=./updated-models
   ```

3. **Replace existing models**:
   ```bash
   mv v2 v2.backup
   mv v2beta2 v2beta2.backup
   cp -r updated-models/v2* .
   ```

4. **Test compatibility**:
   ```bash
   kcl run test-simple.k
   kcl run examples/simple-helmrelease.k
   ```

5. **Update this file** with new version info

6. **Increment module version** in `kcl.mod`

## Change History

### 2025-10-23 - Initial Conversion
- **Flux Version**: v2.7.2
- **Action**: Initial CRD conversion using Dagger KCL module
- **Changes**:
  - Generated v2 and v2beta2 API schemas
  - Created wrapper schemas in main.k
  - Added helper functions for common patterns
  - Implemented Crossplane integration
- **Notes**: First version of flux-helmrelease module

---

**Maintenance**: Update this file whenever CRDs are re-converted or updated.
