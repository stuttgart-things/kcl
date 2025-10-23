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

### CRD to KCL Schema Conversion (Using Dagger Module)

#### Using Dagger KCL Module for Automated Conversion
**Recommended approach** - Use the stuttgart-things/dagger KCL module for automated, reproducible CRD conversion:

- [ ] **Identify target CRDs**: Determine which Crossplane provider or Kubernetes CRDs to convert
  - [ ] Find CRD YAML files in upstream repositories (e.g., GitHub releases, operator repos)
  - [ ] Identify specific CRD versions and API groups needed
  - [ ] Note the CRD URL for automated conversion

- [ ] **Convert CRD using Dagger module** (recommended):
```bash
# Convert CRD from web source (no local download needed)
dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
  --crd-source "https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/main/config/data/flux/v2.7.2/kustomize-controller.yaml" \
  --progress plain \
  export --path=./models

# Alternative: Convert local CRD file
dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
  --crd-file ./my-crd.yaml \
  --progress plain \
  export --path=./models
```

- [ ] **Verify generated models**:
  - [ ] Check `models/` directory structure:
    ```
    models/
    ├── kcl.mod                 # Generated module definition
    ├── k8s/                    # Kubernetes core types
    │   └── apimachinery/pkg/apis/meta/v1/
    ├── v1/                     # API version v1 schemas
    │   └── <resource>_v1_<name>.k
    └── v1beta1/               # API version v1beta1 schemas (if present)
        └── <resource>_v1beta1_<name>.k
    ```
  - [ ] Verify schema structure matches expected CRD specification
  - [ ] Ensure all required/optional fields are correctly typed
  - [ ] Check that imports reference correct Kubernetes types

- [ ] **Integrate generated models into module**:
```bash
# Move generated models into your module directory
mv models/* <module-name>/
cd <module-name>

# Update kcl.mod if needed (merge dependencies)
# The generated kcl.mod provides the base package structure
```

- [ ] **Validate schema generation**:
```bash
# Test schema compilation
cd <module-name>
kcl run v1/<resource-schema>.k

# Verify types resolve correctly
kcl doc v1/<resource-schema>.k
```

- [ ] **Create wrapper schemas** (recommended for complex CRDs):
  - [ ] Simplify complex CRD schemas for easier usage
  - [ ] Add helper functions for common configuration patterns
  - [ ] Provide default values and validation logic
  - [ ] Create examples demonstrating both direct CRD usage and wrapper functions

#### Manual Conversion (Alternative)
For cases where Dagger module is not available:

- [ ] **Download CRD definitions**:
```bash
# Example: Download CRD manually
wget -O my-crd.yaml https://raw.githubusercontent.com/example/operator/main/config/crds/example.yaml
```

- [ ] **Convert using local kcl import**:
```bash
# Import CRD and generate KCL models
kcl import -m crd my-crd.yaml

# Output will be in models/ directory
```

#### Benefits of Dagger Module Approach
- ✅ **Reproducible**: Same conversion results across environments
- ✅ **Automated**: No manual downloads or cleanup needed
- ✅ **Containerized**: Consistent KCL version and tooling
- ✅ **Remote sources**: Direct conversion from URLs
- ✅ **Clean output**: Properly structured with kcl.mod
- ✅ **CI/CD friendly**: Easy integration in pipelines

### Write KCL Code
- [ ] Create main composition file: `main.k`
- [ ] Add required imports:
```kcl
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as k8s
# For CRD-based modules, import generated models:
import models.v1beta1.tf_upbound_io_v1beta1_workspace as workspace
```
- [ ] **Create simplified schemas** (for CRD-based modules):
```kcl
# Wrapper schema for easier usage
schema TerraformWorkspace:
    name: str
    namespace?: str = "default"
    source: "Remote" | "Inline" | "Flux" = "Remote"
    module: str
    variables?: {str: str}
    # ... other simplified fields
```
- [ ] **Implement helper functions** (for CRD-based modules):
```kcl
# Function to generate CRD resources from simplified config
generateTerraformWorkspace = lambda config: TerraformWorkspace -> [workspace.Workspace] {
    [
        workspace.Workspace {
            metadata.name = config.name
            metadata.namespace = config.namespace
            spec.forProvider = {
                source = config.source
                module = config.module
                vars = [{key = k, value = v} for k, v in config.variables] if config.variables else []
            }
        }
    ]
}
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
- [ ] **Test CRD schema compilation**:
```bash
# Test generated CRD models compile correctly
kcl run models/v1beta1/<crd-schema>.k
```
- [ ] **Test helper functions** (for CRD-based modules):
```bash
# Test wrapper functions generate correct resources
kcl run tests/test_main.k
```
- [ ] **Test example usage**:
```bash
# Test practical examples
kcl run examples/simple-workspace.k
```
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
- [ ] **Validate CRD resource structure**:
```bash
# Verify generated YAML matches expected CRD format
kcl run main.k | kubectl apply --dry-run=client -f -
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
