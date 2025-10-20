# Decisions

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
import models.v1beta1.helm_crossplane_io_v1beta1_release as helm

release = helm.Release {
    apiVersion: "helm.crossplane.io/v1beta1"
    kind: "Release"
    metadata: {
        name: "my-helm-release"
    }
    spec: {
        providerConfigRef: { name: "default" }
        forProvider: {
            chart: {
                name: "nginx"
                repository: "https://charts.bitnami.com/bitnami"
                version: "15.0.0"
            }
            namespace: "default"
            values: {
                replicaCount: 2
            }
        }
    }
}
```

**For Kubernetes objects:**
```kcl
import crossplane_provider_kubernetes as k8s

k8sObject = k8s.Object {
    # Use provider version 0.18.0
}
```

**Module versions:**
- Helm provider: `oci://ghcr.io/stuttgart-things/crossplane-helm-provider:0.0.1`
- Kubernetes provider: `crossplane-provider-kubernetes = "0.18.0"`

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
