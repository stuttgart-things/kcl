# Decisions
---

## Mandatory Task Check Before Every Commit

**Date:** 2025-10-23
**Status:** Accepted

**Context:**
To ensure code quality, security, and compliance, every commit must be preceded by a mandatory task check. This includes running pre-commit hooks, linting, secret detection, and any other automated checks defined in the Taskfile or CI pipeline.

**Decision:**
Before every commit, the following must be executed:
1. Run all pre-commit hooks (e.g. `pre-commit run -a`)
2. Run the main Taskfile check (e.g. `task check` or `task mustrun`)
3. Ensure all checks pass before proceeding with the commit

**Benefits:**
- Prevents accidental commits of secrets, broken code, or formatting errors
- Automatisiert die Einhaltung von Projektstandards
- Reduziert manuelle Fehler und erhöht die Zuverlässigkeit

**Enforcement:**
- Commits dürfen nur nach erfolgreichem Task-Check erfolgen
- CI/CD prüft, ob alle Checks bestanden wurden
- Dokumentation und Code-Reviews müssen diese Praxis bestätigen

**Alternatives considered:**
- Commit ohne Checks (abgelehnt – erhöht Fehlerquote und Sicherheitsrisiko)

---
## Use Crossplane-Compliant Variable Structure for All Dagger Functions

**Date:** 2024-10-19
**Status:** Accepted

**Context:**
When building Dagger functions that interact with Crossplane resources, we need a consistent way to access configuration values. Variables should follow Crossplane's structure to ensure compatibility and predictability.

**Decision:**
Always use the Crossplane-compliant variable access pattern:
```
name = option("params")?.oxr?.spec?.name or "default-value"
```

**Pattern breakdown:**
- `option("params")` - Access the params option
- `?.oxr?.spec` - Navigate through Crossplane's composite resource structure
- `?.name` - Access the specific field with safe navigation
- `or "default-value"` - Provide sensible fallback

**Examples:**
```python
# Get cluster name
cluster = option("params")?.oxr?.spec?.clusterName or "dev-cluster"

# Get region
region = option("params")?.oxr?.spec?.region or "us-east-1"

# Get replica count
replicas = option("params")?.oxr?.spec?.replicas or 3

# Get environment
env = option("params")?.oxr?.spec?.environment or "development"
```

**Benefits:**
- Consistent across all Dagger functions
- Safe navigation prevents null reference errors
- Always provides fallback values
- Matches Crossplane XR (Composite Resource) structure
- Easy to read and maintain

**Alternatives considered:**
- Direct access without safe navigation (rejected - causes errors on missing values)
- Flat variable structure (rejected - doesn't match Crossplane conventions)
- Environment variables only (rejected - less flexible)

**Enforcement:**
- Code reviews check for this pattern
- All new functions must follow this structure
- Document in function comments when deviating

---

## Use Standardized Crossplane Provider Modules for KCL

**Date:** 2024-10-20
**Status:** Accepted

**Context:**
When writing KCL composition functions for Crossplane, we need to use provider modules to create Helm releases and Kubernetes objects. These modules must be sourced consistently across all KCL compositions used with crossplane-function-kcl.

**Decision:**
Use the following KCL modules for Crossplane providers:

**For Helm releases:**
```kcl
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm

# --- Get XR spec fields ---
name = option("params")?.oxr?.spec?.name or "my-release"
clusterName = option("params")?.oxr?.spec?.clusterName or "default"
targetNamespace = option("params")?.oxr?.spec?.targetNamespace or "default"

release = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = name
    }
    spec = {
        providerConfigRef: {
            name = clusterName
        }
        forProvider: {
            chart: {
                name = "nginx"
                repository = "https://charts.bitnami.com/bitnami"
                version = "15.0.0"
            }
            namespace = targetNamespace
            values: {
                replicaCount = 2
            }
        }
    }
}

items = [release]
```

**For Kubernetes objects:**
```kcl
import crossplane_provider_kubernetes as k8s

k8sObject = k8s.Object {
    # Use provider version 0.18.0
}
```

**Module versions and kcl.mod configuration:**
```xml
[dependencies]
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }
crossplane-provider-kubernetes = "0.18.0"
```

**Rationale:**
- Consistent provider versions across all KCL compositions
- Stuttgart Things Helm provider provides required custom functionality
- Kubernetes provider 0.18.0 is stable and tested
- Works seamlessly with crossplane-function-kcl container runtime
- Standard import pattern ensures compatibility

**Benefits:**
- All KCL compositions use same provider versions
- Predictable behavior in crossplane-function-kcl
- Simplified debugging and troubleshooting
- Clear dependency management
- Type-safe Helm release definitions

**Alternatives considered:**
- Using latest tags (rejected - breaks composition reproducibility)
- Different providers per composition (rejected - maintenance nightmare)
- Direct YAML generation (rejected - loses KCL type safety)

**Enforcement:**
- All KCL composition files must import and use these specific versions
- Code reviews verify correct module usage and import patterns
- Update this decision when upgrading provider versions

---

## Standardized Boolean Handling in KCL Modules

**Date:** 2024-10-20
**Status:** Accepted

**Context:**
Boolean values in KCL require explicit handling to correctly distinguish between `false` values and undefined/null values. Without proper handling, `false` values get treated as truthy due to KCL's `or` operator behavior.

**Decision:**
Always use explicit False checking pattern for boolean flags:

**Pattern:**
```kcl
# Explicit False checking for boolean values
_enabledValue = option("params")?.oxr?.spec?.enabled
enabled = False if _enabledValue == False else True

# Alternative short form for simple cases
enabled = option("params")?.oxr?.spec?.enabled if option("params")?.oxr?.spec?.enabled != None else True
```

**Complete example with conditional object creation:**
```kcl
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm

# --- Get XR spec fields with proper boolean handling ---
name = option("params")?.oxr?.spec?.name or "vault-config"
clusterName = option("params")?.oxr?.spec?.clusterName or "default"

# Boolean flags with explicit False checking
_csiEnabledValue = option("params")?.oxr?.spec?.csiEnabled
csiEnabled = False if _csiEnabledValue == False else True

_vsoEnabledValue = option("params")?.oxr?.spec?.vsoEnabled
vsoEnabled = False if _vsoEnabledValue == False else True

# Create releases
csiRelease = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "secrets-store-csi-driver-${name}"
    }
    spec = {
        providerConfigRef: { name = clusterName }
        forProvider: {
            chart: {
                name = "secrets-store-csi-driver"
                repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
                version = "1.4.0"
            }
            namespace = "secrets-store-csi"
        }
    }
}

vsoRelease = helm.Release {
    # ... similar structure
}

# Conditional items array generation
items = ([csiRelease] if csiEnabled else []) + ([vsoRelease] if vsoEnabled else [])
```

**Key principles:**
1. **Explicit False checking**: Use `== False` comparison, not `or` operator for booleans
2. **Intermediate variables**: Store the raw value first, then apply logic
3. **Default to True**: When undefined, boolean flags should default to enabled/true
4. **Conditional arrays**: Use array concatenation with conditionals for optional resources

**Common patterns:**
```kcl
# Single boolean check
_value = option("params")?.oxr?.spec?.enabled
enabled = False if _value == False else True

# Multiple boolean checks
_debug = option("params")?.oxr?.spec?.debug
_verbose = option("params")?.oxr?.spec?.verbose
debug = False if _debug == False else True
verbose = False if _verbose == False else True

# Conditional object creation
object = SomeObject { ... } if enabled else None

# Conditional array inclusion
items = [required_object] + ([optional_object] if enabled else [])
```

**Benefits:**
- Correctly handles `false` vs `undefined` distinction
- Predictable behavior across all KCL modules
- Safe defaults when values are not provided
- Clear intention in code

**Alternatives considered:**
- Using `or` operator (rejected - treats `false` as falsy, defaults to `True`)
- No explicit handling (rejected - inconsistent behavior)
- Always requiring boolean values (rejected - reduces flexibility)

**Enforcement:**
- All boolean parameters in KCL modules must use this pattern
- Code reviews verify correct boolean handling
- Documentation examples should demonstrate this pattern
- Test cases should verify both `true` and `false` scenarios

---

## Mandatory Crossplane Composition Resource Name Annotations

**Date:** 2024-10-20
**Status:** Accepted

**Context:**
When creating KCL modules for Crossplane compositions, every resource needs proper identification for debugging, monitoring, and resource management. Crossplane uses `krm.kcl.dev/composition-resource-name` annotations to uniquely identify resources within compositions.

**Decision:**
**ALWAYS** add `krm.kcl.dev/composition-resource-name` annotation to every Crossplane resource in KCL modules.

**Pattern:**
```kcl
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import crossplane_provider_kubernetes.v1alpha2.kubernetes_crossplane_io_v1alpha2_object as k8s

# --- Get XR spec fields ---
configName = option("params")?.oxr?.spec?.name or "default-config"

# Helm Release with annotation
release = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "my-release-{}".format(configName)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "my-service-{}".format(configName)
        }
    }
    spec = {
        # ... release configuration
    }
}

# Kubernetes Object with annotation
namespace = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "namespace-{}".format(namespaceName)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "my-namespace-{}".format(namespaceName)
        }
    }
    spec = {
        # ... object configuration
    }
}
```

**Naming Convention Standards:**

| Resource Type | Annotation Pattern | Example |
|---------------|-------------------|---------|
| **Helm Releases** | `{module}-{service}-{configName}` | `vault-csi-prod`, `vault-vso-prod` |
| **Namespaces** | `{module}-namespace-{namespace-name}` | `vault-namespace-production` |
| **ServiceAccounts** | `{module}-serviceaccount-{auth-name}` | `vault-serviceaccount-auth-prod` |
| **Secrets** | `{module}-secret-{auth-name}` | `vault-secret-auth-prod` |
| **ClusterRoleBindings** | `{module}-clusterrolebinding-{auth-name}` | `vault-clusterrolebinding-auth-prod` |
| **Token Readers** | `{module}-token-reader-{auth-name}` | `vault-token-reader-auth-prod` |

**Complete Example (vault-config module):**
```kcl
# CSI Driver Release
csiRelease = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "secrets-store-csi-driver-{}".format(configName)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-csi-{}".format(configName)
        }
    }
    # ... rest of configuration
}

# ServiceAccount
serviceAccount = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "serviceaccount-{}".format(auth.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-serviceaccount-{}".format(auth.name)
        }
    }
    # ... rest of configuration
}

# Token Reader
tokenReader = k8s.Object {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "token-reader-{}".format(auth.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-token-reader-{}".format(auth.name)
        }
    }
    # ... rest of configuration
}
```

**Benefits:**
- **Better debugging**: Easy identification of resources in Crossplane events and logs
- **Resource tracking**: Clear mapping between composition intent and actual resources
- **Monitoring**: Consistent resource naming for alerting and metrics
- **Documentation**: Self-documenting resource purpose and ownership
- **Troubleshooting**: Fast identification of failed/stuck resources

**Variable handling:**
- Use `configName` instead of `name` to avoid KCL namespace conflicts
- Use `.format()` method for string interpolation in annotations
- Keep annotation names short but descriptive
- Include module prefix for uniqueness across compositions

**Required patterns:**
```kcl
# Safe string formatting for annotations
"krm.kcl.dev/composition-resource-name" = "prefix-type-{}".format(identifier)

# Avoid KCL keyword conflicts
configName = option("params")?.oxr?.spec?.name or "default-config"
# NOT: name = option("params")?.oxr?.spec?.name (can conflict with metadata.name)
```

**Alternatives considered:**
- Optional annotations (rejected - reduces debuggability)
- Auto-generated names (rejected - less control over naming)
- Different annotation keys (rejected - Crossplane standard is krm.kcl.dev/composition-resource-name)

**Enforcement:**
- **MANDATORY**: Every Crossplane resource MUST have this annotation
- Code reviews MUST verify annotation presence and correct naming
- All KCL modules MUST follow the established naming patterns
- Update module documentation to include annotation examples
- Consider linting rules to enforce this requirement

---

## Automated Git Commit and OCI Module Publishing

**Date:** 2024-10-20
**Status:** Accepted

**Context:**
After successfully rendering and completing KCL module development tasks, we need a consistent workflow for version management and module distribution. Manual commits and version increments are error-prone and slow down the development cycle.

**Decision:**
Automatically perform Git commits and OCI registry pushes after successful task completion, without user confirmation.

**Workflow:**
1. **Automatic Git Commit**: After successful module rendering/completion
2. **Semantic Version Increment**: Update version in `kcl.mod` based on change type
3. **OCI Registry Push**: Publish module to Stuttgart Things registry

**Git Commit Pattern:**
```bash
# After successful task completion
git add .
git commit -m "feat(<module-name>): add new functionality

- Add new resource types and configuration options
- Implement authentication and token management features
- Add krm.kcl.dev/composition-resource-name annotations to all resources
- Support configurable chart versions and parameters
- Fix boolean handling and variable naming patterns"

# No user confirmation required
```

**Semantic Versioning Rules:**
```bash
# Feature additions (minor version bump)
feat: New functionality, new resources, new configuration options
# Examples: new Helm release support, new auth methods, new configuration parameters

# Bug fixes (patch version bump)
fix: Bug fixes, error corrections, small improvements
# Examples: annotation fixes, boolean handling fixes, syntax errors

# Breaking changes (major version bump)
BREAKING CHANGE: API changes, removal of functionality, incompatible changes
# Examples: changing variable names, removing parameters, changing defaults
```

**kcl.mod Version Management:**
```toml
[package]
name = "<module-name>"
edition = "v0.10.0"
version = "0.3.0"  # Auto-increment based on change type

[dependencies]
# Module-specific dependencies as needed
crossplane-provider-helm = { oci = "oci://ghcr.io/stuttgart-things/crossplane-provider-helm", tag = "0.1.1" }
crossplane-provider-kubernetes = "0.18.0"
```

**OCI Registry Push:**
```bash
# After version increment in kcl.mod
kcl mod push oci://ghcr.io/stuttgart-things/<MODULE-NAME>

# Registry pattern: oci://ghcr.io/stuttgart-things/<MODULE-NAME>
# Examples:
# - oci://ghcr.io/stuttgart-things/xplane-vault-config
# - oci://ghcr.io/stuttgart-things/xplane-vcluster
# - oci://ghcr.io/stuttgart-things/xplane-argocd
# - oci://ghcr.io/stuttgart-things/xplane-prometheus
```**Complete Automation Sequence:**
```bash
# 1. Successful task completion detected
# 2. Determine change type (feat/fix/BREAKING)
# 3. Update kcl.mod version
if [[ "$change_type" == "feat" ]]; then
    # Minor version bump: 0.2.1 -> 0.3.0
    new_version=$(increment_minor_version)
elif [[ "$change_type" == "fix" ]]; then
    # Patch version bump: 0.2.1 -> 0.2.2
    new_version=$(increment_patch_version)
elif [[ "$change_type" == "BREAKING" ]]; then
    # Major version bump: 0.2.1 -> 1.0.0
    new_version=$(increment_major_version)
fi

# 4. Update kcl.mod file
sed -i "s/version = \".*\"/version = \"$new_version\"/" kcl.mod

# 5. Git commit with descriptive message
git add .
git commit -m "$commit_type($module_name): $commit_message"

# 6. Push to OCI registry
kcl mod push oci://ghcr.io/stuttgart-things/$module_name

# 7. Git push to working branch
git push origin $current_branch
```

**Change Type Detection:**
- **feat**: Adding new resources, configuration options, functionality (any module)
- **fix**: Bug fixes, syntax corrections, annotation fixes (any module)
- **BREAKING CHANGE**: API changes, parameter removals, incompatible updates (any module)

**Module Name Extraction:**
```bash
# Extract module name from kcl.mod (generic for any module)
module_name=$(grep '^name = ' kcl.mod | cut -d '"' -f 2)
# Examples: "xplane-vault-config", "xplane-argocd", "xplane-prometheus"
```

**Registry Benefits:**
- **Versioned modules**: Each change gets proper semantic version
- **Immutable releases**: Published versions cannot be overwritten
- **Dependency management**: Other compositions can pin specific versions
- **Distribution**: Easy sharing across teams and environments
- **Rollback capability**: Can revert to previous working versions

**Commit Message Format:**
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Examples:**
```bash
# Feature addition
feat(xplane-prometheus): add ServiceMonitor support for metrics collection

# Bug fix
fix(xplane-argocd): correct boolean handling for false values

# Breaking change
feat(xplane-vcluster): rename configName variable for consistency

BREAKING CHANGE: Variable 'name' renamed to 'configName' to avoid KCL conflicts
```**Benefits:**
- **Consistency**: All modules follow same versioning and publishing workflow
- **Automation**: No manual steps after successful development
- **Traceability**: Clear commit history with semantic versioning
- **Distribution**: Automatic module availability in registry
- **Reliability**: Reduces human error in version management
- **Speed**: Faster development cycles without manual publishing steps

**Alternatives considered:**
- Manual commit and push (rejected - error-prone, slow)
- User confirmation for each step (rejected - interrupts workflow)
- Different registry providers (rejected - Stuttgart Things standardized on GitHub)
- Different versioning schemes (rejected - semantic versioning is industry standard)

**Enforcement:**
- All KCL module tasks MUST use this automated workflow
- No manual version increments in kcl.mod files
- Commit messages MUST follow conventional commit format
- Registry pushes MUST use stuttgart-things organization namespace
- Working branch pushes happen after successful OCI publication

---

## CRD to KCL Schema Conversion Standards

**Date:** 2024-10-21
**Status:** Accepted

**Context:**
When creating KCL modules for Crossplane providers that use Custom Resource Definitions (CRDs), we need a standardized approach for converting CRDs into type-safe KCL schemas while providing developer-friendly abstractions.

**Decision:**
Use automatic CRD import with `kcl import` command followed by simplified wrapper schemas for complex CRD structures.

**CRD Import Workflow:**
```bash
# 1. Download target CRD from upstream repository
wget -O tf_workspaces.yaml https://raw.githubusercontent.com/crossplane-contrib/provider-terraform/main/package/crds/tf.upbound.io_workspaces.yaml

# 2. Import CRD and generate KCL models
kcl import -m crd tf_workspaces.yaml

# 3. Verify generated models structure
ls -la models/v1beta1/
# Expected: tf_upbound_io_v1beta1_workspace.k

# 4. Test schema compilation
kcl run models/v1beta1/tf_upbound_io_v1beta1_workspace.k
```

**Generated Schema Structure:**
```kcl
# Auto-generated in models/v1beta1/tf_upbound_io_v1beta1_workspace.k
schema Workspace:
    r"""
    A Workspace of Terraform Configuration.
    """
    apiVersion: "tf.upbound.io/v1beta1" = "tf.upbound.io/v1beta1"
    kind: "Workspace" = "Workspace"
    metadata?: v1.ObjectMeta
    spec: TfUpboundIoV1beta1WorkspaceSpec
    status?: TfUpboundIoV1beta1WorkspaceStatus

# Full CRD spec with all fields imported automatically
schema TfUpboundIoV1beta1WorkspaceSpec:
    deletionPolicy?: "Orphan" | "Delete" = "Delete"
    forProvider: TfUpboundIoV1beta1WorkspaceSpecForProvider
    managementPolicies?: [str] = ["*"]
    # ... complete CRD structure
```

**Wrapper Schema Pattern:**
```kcl
# main.k - Create simplified schemas for easier usage
import models.v1beta1.tf_upbound_io_v1beta1_workspace as workspace

# Simplified wrapper schema
schema TerraformWorkspace:
    """
    Simplified Terraform workspace configuration with common defaults.
    """
    name: str
    namespace?: str = "default"
    labels?: {str: str}
    annotations?: {str: str}

    # Terraform configuration
    source: "Remote" | "Inline" | "Flux" = "Remote"
    module: str
    entrypoint?: str = ""
    inlineFormat?: "HCL" | "JSON" = "HCL"

    # Variables
    variables?: {str: str}
    variableFiles?: [TerraformVarFile]
    environmentVariables?: [TerraformEnvVar]

    # Provider configuration
    providerConfigRef?: str = "default"
    connectionSecret?: TerraformConnectionSecret
    managementPolicies?: [str] = ["*"]
    deletionPolicy?: "Delete" | "Orphan" = "Delete"

# Helper function to convert simplified config to full CRD
generateTerraformWorkspace = lambda config: TerraformWorkspace -> [workspace.Workspace] {
    [
        workspace.Workspace {
            metadata = {
                name = config.name
                namespace = config.namespace or "default"
                labels = config.labels or {}
                annotations = config.annotations or {}
            }
            spec = {
                deletionPolicy = config.deletionPolicy
                managementPolicies = config.managementPolicies
                providerConfigRef = {
                    name = config.providerConfigRef
                } if config.providerConfigRef else Undefined
                forProvider = {
                    source = config.source
                    module = config.module
                    entrypoint = config.entrypoint
                    vars = [{key = k, value = v} for k, v in config.variables] if config.variables else Undefined
                    # ... map other fields
                }
            }
        }
    ]
}
```

**Helper Function Patterns:**
```kcl
# Pattern 1: Simple Git-based workspace
gitTerraformWorkspace = lambda name: str, gitUrl: str, path: str, variables: {str: str} -> [workspace.Workspace] {
    generateTerraformWorkspace(TerraformWorkspace {
        name = name
        source = "Remote"
        module = gitUrl + ("/" + path if path else "")
        variables = variables
    })
}

# Pattern 2: Inline Terraform code
inlineTerraformWorkspace = lambda name: str, terraformCode: str, format: str, variables: {str: str} -> [workspace.Workspace] {
    generateTerraformWorkspace(TerraformWorkspace {
        name = name
        source = "Inline"
        module = terraformCode
        inlineFormat = format
        variables = variables
    })
}

# Pattern 3: Workspace with connection secrets
secretTerraformWorkspace = lambda name: str, gitUrl: str, secretName: str, secretNamespace: str, variables: {str: str} -> [workspace.Workspace] {
    generateTerraformWorkspace(TerraformWorkspace {
        name = name
        source = "Remote"
        module = gitUrl
        variables = variables
        connectionSecret = TerraformConnectionSecret {
            name = secretName
            namespace = secretNamespace
        }
    })
}
```

**Testing Standards:**
```kcl
# tests/test_main.k
import ..main as terraform

test_git_workspace = lambda {
    workspaces = terraform.gitTerraformWorkspace(
        "test-workspace",
        "https://github.com/example/terraform.git",
        "modules/vpc",
        {"region": "us-west-2"}
    )

    assert len(workspaces) == 1
    assert workspaces[0].metadata.name == "test-workspace"
    assert workspaces[0].spec.forProvider.source == "Remote"
    assert workspaces[0].spec.forProvider.module == "https://github.com/example/terraform.git/modules/vpc"
}

# Run tests
test_git_workspace()
print("✅ All tests passed!")
```

**File Structure Standards:**
```
crossplane-provider-<provider>/
├── README.md                    # Comprehensive documentation
├── kcl.mod                      # Module definition
├── main.k                       # Wrapper schemas and helper functions
├── models/v1beta1/              # Auto-generated CRD schemas
│   └── <provider>_<version>_<resource>.k
├── examples/                    # Usage examples
│   └── simple-workspace.k       # Practical examples
├── tests/                       # Test suite
│   └── test_main.k              # Comprehensive tests
└── <crd-source>.yaml           # Original CRD for reference
```

**Module Naming Convention:**
- **Module name**: `crossplane-provider-<provider-name>`
- **Examples**: `crossplane-provider-terraform`, `crossplane-provider-aws`, `crossplane-provider-gcp`
- **OCI registry**: `oci://ghcr.io/stuttgart-things/crossplane-provider-<provider-name>`

**Documentation Requirements:**
```markdown
# Module README.md structure
## Features
- List of supported CRD resources
- Helper functions provided
- Integration capabilities

## Installation
- OCI registry import instructions
- Dependency requirements

## Usage
- Quick start examples for each helper function
- Advanced configuration examples
- API reference with all fields documented

## Generated CRD Models
- List of imported CRDs and their purposes
- Link to upstream CRD documentation

## Development
- Testing instructions
- Contributing guidelines
```

**Benefits:**
- **Type Safety**: Full CRD schema validation at compile time
- **Developer Experience**: Simplified schemas reduce complexity
- **Maintainability**: Auto-generated schemas stay in sync with upstream CRDs
- **Flexibility**: Direct access to full CRD API when needed
- **Testing**: Comprehensive validation of generated resources
- **Documentation**: Clear examples and API reference

**CRD Source Management:**
```bash
# Track CRD sources and versions
echo "# CRD Sources" > crd-sources.md
echo "- Terraform Provider Workspace: https://github.com/crossplane-contrib/provider-terraform/blob/main/package/crds/tf.upbound.io_workspaces.yaml" >> crd-sources.md
echo "- Version: v0.15.0" >> crd-sources.md
echo "- Import Date: $(date)" >> crd-sources.md
```

**Alternatives considered:**
- Manual schema creation (rejected - error-prone, out of sync with upstream)
- Direct CRD usage without wrappers (rejected - too complex for users)
- Different import tools (rejected - `kcl import` is official and reliable)
- Flat schema structure (rejected - loses CRD structure benefits)

**Enforcement:**
- All CRD-based modules MUST use `kcl import -m crd` for schema generation
- Generated schemas MUST NOT be manually edited (marked with "DO NOT EDIT" header)
- Wrapper schemas MUST provide simplified developer interfaces
- Helper functions MUST cover common usage patterns
- Tests MUST validate both wrapper functions and direct CRD usage
- Documentation MUST include both simple and advanced examples

````

---

## Use Dagger KCL Module for CRD to KCL Schema Conversion

**Date:** 2025-10-23
**Status:** Accepted

**Context:**
Converting Kubernetes Custom Resource Definitions (CRDs) to KCL schemas is a critical task when building KCL modules for Crossplane providers, Flux resources, or any Kubernetes operator. Manual conversion using `kcl import` requires downloading files, managing dependencies, and ensuring consistent tooling versions across development environments.

**Decision:**
Use the `stuttgart-things/dagger` KCL module for automated CRD-to-KCL schema conversion instead of manual local conversion.

**Dagger Module Usage:**
```bash
# Convert CRD from web source (recommended)
dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
  --crd-source "https://raw.githubusercontent.com/controlplaneio-fluxcd/flux-operator/main/config/data/flux/v2.7.2/kustomize-controller.yaml" \
  --progress plain \
  export --path=./generated-models

# Convert local CRD file
dagger call -m github.com/stuttgart-things/dagger/kcl@latest convert-crd \
  --crd-file ./my-crd.yaml \
  --progress plain \
  export --path=./generated-models
```

**Generated Structure:**
```
generated-models/
├── kcl.mod                          # Module definition
├── k8s/apimachinery/pkg/apis/meta/v1/  # K8s core types
├── v1/                              # API version v1 schemas
│   └── <group>_v1_<resource>.k
└── v1beta1/                         # API version v1beta1 schemas
    └── <group>_v1beta1_<resource>.k
```

**Benefits:**
- **Reproducibility**: Consistent conversion results across all environments
- **No Local Dependencies**: No need to install/manage KCL CLI locally
- **Remote Sources**: Direct conversion from URLs without manual downloads
- **CI/CD Ready**: Easy integration in pipelines
- **Containerized**: Isolated environment prevents conflicts

**Enforcement:**
- All new KCL modules with CRD dependencies MUST use Dagger module
- Document CRD source URLs in module README
- Track CRD versions in `crd-sources.md` file
- Re-run conversion when upstream CRDs are updated
