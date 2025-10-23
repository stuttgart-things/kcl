# CRD Sources

This file tracks the Custom Resource Definitions (CRDs) used in this module and their conversion details.

## Flux Kustomization Controller

### Source Information
- **Upstream Repository**: [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator)
- **CRD URL**: https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/kustomize-controller.yaml
- **Flux Version**: v2.7.2
- **Commit SHA**: d78658085afc5e2de06358f35f05ef317de6a25d
- **Conversion Date**: 2025-10-23
- **Converted By**: stuttgart-things/dagger KCL module

### CRD Details
- **API Group**: kustomize.toolkit.fluxcd.io
- **Kinds**: Kustomization
- **API Versions**:
  - v1 (primary, 783 lines)
  - v1beta2 (compatibility, 755 lines)

### Conversion Command
```bash
dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
  --crd-source "https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/kustomize-controller.yaml" \
  --progress plain \
  export --path=./generated-models
```

### Generated Files
- `v1/kustomize_toolkit_fluxcd_io_v1_kustomization.k`
- `v1beta2/kustomize_toolkit_fluxcd_io_v1beta2_kustomization.k`
- `k8s/apimachinery/pkg/apis/meta/v1/object_meta.k`
- `k8s/apimachinery/pkg/apis/meta/v1/owner_reference.k`
- `k8s/apimachinery/pkg/apis/meta/v1/managed_fields_entry.k`
- `kcl.mod` (base package structure)

### Update Instructions

When Flux releases a new version:

1. **Check for new version**:
   ```bash
   # Visit https://github.com/controlplaneio-fluxcd/flux-operator/releases
   # Or check Flux releases: https://github.com/fluxcd/flux2/releases
   ```

2. **Update CRD URL** with new version:
   ```bash
   FLUX_VERSION="v2.8.0"  # Update to new version
   CRD_URL="https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/main/config/data/flux/${FLUX_VERSION}/kustomize-controller.yaml"
   ```

3. **Re-convert using Dagger**:
   ```bash
   dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
     --crd-source "${CRD_URL}" \
     --progress plain \
     export --path=./updated-models
   ```

4. **Replace existing models**:
   ```bash
   # Backup current models
   mv v1 v1.backup
   mv v1beta2 v1beta2.backup
   mv k8s k8s.backup

   # Copy new models
   cp -r updated-models/* .
   ```

5. **Test compatibility**:
   ```bash
   # Test schema compilation
   kcl run v1/kustomize_toolkit_fluxcd_io_v1_kustomization.k

   # Test examples
   kcl run examples/simple-kustomization.k

   # Test Crossplane integration
   kcl run main.k
   ```

6. **Update this file**:
   - Update Flux Version
   - Update Commit SHA
   - Update Conversion Date
   - Update line counts if changed

7. **Increment module version** in `kcl.mod`:
   - Breaking changes: Major version bump
   - New fields: Minor version bump
   - Bug fixes: Patch version bump

## Verification

### CRD Checksum
```bash
# Verify CRD integrity
curl -sL "https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/d78658085afc5e2de06358f35f05ef317de6a25d/config/data/flux/v2.7.2/kustomize-controller.yaml" | sha256sum
# Expected: <calculated on conversion date>
```

### Schema Validation
```bash
# Validate generated schemas compile
kcl run v1/kustomize_toolkit_fluxcd_io_v1_kustomization.k

# Check for syntax errors
kcl vet v1/kustomize_toolkit_fluxcd_io_v1_kustomization.k
```

## Change History

### 2025-10-23 - Initial Conversion
- **Flux Version**: v2.7.2
- **Action**: Initial CRD conversion using Dagger KCL module
- **Changes**:
  - Generated v1 and v1beta2 API schemas
  - Created wrapper schemas in main.k
  - Added helper functions for common patterns
  - Implemented Crossplane integration
- **Notes**: First version of flux-kustomization module

---

**Maintenance**: Update this file whenever CRDs are re-converted or updated.
