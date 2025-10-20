# Tasks

## Setup KCL Module for Crossplane Compositions

### Module Creation
- [ ] Create module folder: `mkdir -p <module-name>`
- [ ] Initialize KCL module: `cd <module-name> && kcl mod init`
- [ ] Verify `kcl.mod` file was created with correct name and initial version

### Add Dependencies
- [ ] Add Crossplane Helm provider: `kcl mod add oci://ghcr.io/stuttgart-things/crossplane-provider-helm --tag 0.1.1`
- [ ] Add Crossplane Kubernetes provider: `kcl mod add crossplane-provider-kubernetes@0.18.0` (if needed)
- [ ] Verify `kcl.mod` dependencies section is correctly configured
- [ ] Add other module-specific dependencies: `kcl mod add <package>` (as needed)

### Write KCL Code
- [ ] Create main composition file: `main.k`
- [ ] Add required imports:
```kcl
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as k8s
```
- [ ] Implement Crossplane variable pattern:
```kcl
configName = option("params")?.oxr?.spec?.name or "default-config"
clusterName = option("params")?.oxr?.spec?.clusterName or "default"
```
- [ ] Add boolean handling with explicit False checking:
```kcl
_enabledValue = option("params")?.oxr?.spec?.enabled
enabled = False if _enabledValue == False else True
```
- [ ] Add krm.kcl.dev/composition-resource-name annotations to ALL resources
- [ ] Generate items array with conditional resources
- [ ] Add inline comments for variable usage and patterns

### Testing
- [ ] Test with minimal params:
```bash
kcl run main.k -D params='{"oxr":{"spec":{"clusterName":"test"}}}'
```
- [ ] Test with full configuration:
```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "prod-config",
      "clusterName": "prod-cluster",
      "enabled": true,
      "namespace": "production"
    }
  }
}'
```
- [ ] Test boolean false handling:
```bash
kcl run main.k -D params='{"oxr":{"spec":{"enabled":false}}}'
```
- [ ] Test with empty params to verify fallback values:
```bash
kcl run main.k -D params='{}'
```
- [ ] Verify all krm.kcl.dev/composition-resource-name annotations are present
- [ ] Test YAML output and apply to cluster (if applicable)

### Documentation
- [ ] Create comprehensive `README.md` with:
  - [ ] Module description and features
  - [ ] Usage examples for all scenarios
  - [ ] Variable reference table
  - [ ] Generated resources documentation
  - [ ] Crossplane integration notes
- [ ] Document required XR spec fields and defaults
- [ ] Add example `kcl run` commands for different use cases
- [ ] Document krm.kcl.dev/composition-resource-name patterns used

### Git and OCI Publication
- [ ] Ensure all changes are tested and working
- [ ] Determine change type (feat/fix/BREAKING CHANGE)
- [ ] **AUTOMATIC**: Git commit with conventional message format
- [ ] **AUTOMATIC**: Semantic version increment in `kcl.mod`
- [ ] **AUTOMATIC**: Push to OCI registry `oci://ghcr.io/stuttgart-things/<module-name>`
- [ ] **AUTOMATIC**: Git push to working branch
- [ ] Verify module is available in OCI registry
- [ ] Test module import from registry:
```bash
kcl mod add oci://ghcr.io/stuttgart-things/<module-name>
```

### Post-Publication Validation
- [ ] Verify module can be imported by other compositions
- [ ] Check OCI registry for correct version tags
- [ ] Validate semantic versioning is correct
- [ ] Test module in downstream compositions (if applicable)
