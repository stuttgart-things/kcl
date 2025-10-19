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
