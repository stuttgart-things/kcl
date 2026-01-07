# Making KCL Modules Crossplane Composition Compatible

A guide to creating KCL modules that work both standalone and with Crossplane Compositions.

## Quick Overview

Crossplane Compositions pass data in this format:

```json
{
  "oxr": {
    "spec": {
      "field1": "value1",
      "field2": "value2"
    }
  }
}
```

Your KCL module needs to:

- Accept `params` option containing the above structure
- Extract values from `params.oxr.spec`
- Return `items = [...]` array in composition mode
- Support direct option passing for standalone use

## Basic Pattern

### Simple ConfigMap Example

```kcl
# main.k
# --- Read parameters (Composition format) ---
_params = option("params") or {}
_spec = _params?.oxr?.spec or {}

# --- Extract fields with fallbacks ---
_configName = _spec?.configName or option("configName") or "my-config"
_namespace = _spec?.namespace or option("namespace") or "default"
_data = _spec?.data or option("data") or {}
_providerConfig = _spec?.providerConfig or option("providerConfig") or "kubernetes-provider"

# --- Generate the ConfigMap ---
_configMap = {
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
        name = _configName
        namespace = _namespace
    }
    data = _data
}

# --- Wrap in Crossplane Object ---
_crossplaneObject = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {
        name = _configName
        namespace = "default"
    }
    spec = {
        forProvider = {
            manifest = _configMap
        }
        providerConfigRef = {
            name = _providerConfig
        }
    }
}

# --- Output based on mode ---
if _params != {}:
    # Composition mode: return items array
    items = [_crossplaneObject]
else:
    # Direct mode: return single resource
    _crossplaneObject
```

## Usage Examples

### 1. Direct Mode (Standalone)

```bash
kcl run main.k \
  -D configName="app-config" \
  -D namespace="production" \
  -D 'data={"APP_ENV": "prod", "LOG_LEVEL": "info"}' \
  -D providerConfig="kubernetes-provider"
```

Output: Single Crossplane Object resource

### 2. Composition Mode (Crossplane)

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "configName": "app-config",
      "namespace": "production",
      "data": {
        "APP_ENV": "prod",
        "LOG_LEVEL": "info"
      },
      "providerConfig": "kubernetes-provider"
    }
  }
}'
```

Output: `items` array for Crossplane Composition

## Complete Example with Secret

```kcl
# main.k - Secret with optional Crossplane wrapping
_params = option("params") or {}
_spec = _params?.oxr?.spec or {}

# Extract parameters
_secretName = _spec?.secretName or option("secretName") or "my-secret"
_namespace = _spec?.namespace or option("namespace") or "default"
_stringData = _spec?.stringData or option("stringData") or {}
_providerConfig = _spec?.providerConfig or option("providerConfig") or "kubernetes-provider"
_wrapInCrossplane = _spec?.wrapInCrossplane or option("wrapInCrossplane") or True

# Generate Secret
_secret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = _secretName
        namespace = _namespace
    }
    type = "Opaque"
    stringData = _stringData
}

# Crossplane Object wrapper
_crossplaneObject = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {
        name = _secretName
        namespace = "default"
    }
    spec = {
        forProvider = {
            manifest = _secret
        }
        providerConfigRef = {
            name = _providerConfig
        }
    }
}

# Output logic
_resource = _crossplaneObject if _wrapInCrossplane else _secret

if _params != {}:
    items = [_resource]
else:
    _resource
```

### Usage: Direct - Wrapped

```bash
kcl run main.k \
  -D secretName="db-credentials" \
  -D namespace="production" \
  -D 'stringData={"username": "admin", "password": "secret123"}'
```

### Usage: Direct - Unwrapped

```bash
kcl run main.k \
  -D wrapInCrossplane=false \
  -D secretName="db-credentials" \
  -D 'stringData={"username": "admin"}'
```

### Usage: Composition Mode

```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "secretName": "db-credentials",
      "namespace": "production",
      "stringData": {
        "username": "admin",
        "password": "secret123"
      }
    }
  }
}'
```

## Crossplane Resources

### XRD (CompositeResourceDefinition)

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xconfigs.example.io
spec:
  group: example.io
  names:
    kind: XConfig
    plural: xconfigs
  claimNames:
    kind: Config
    plural: configs
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              configName:
                type: string
              namespace:
                type: string
                default: "default"
              data:
                type: object
                additionalProperties:
                  type: string
              providerConfig:
                type: string
                default: "kubernetes-provider"
            required:
            - configName
            - data
```

### Composition

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: config-kcl
spec:
  compositeTypeRef:
    apiVersion: example.io/v1alpha1
    kind: XConfig

  mode: Pipeline
  pipeline:
  - step: render-kcl
    functionRef:
      name: function-kcl
    input:
      apiVersion: krm.kcl.dev/v1alpha1
      kind: KCLRun
      spec:
        source: oci://ghcr.io/your-org/kcl-config:v1.0.0
```

### Claim

```yaml
apiVersion: example.io/v1alpha1
kind: Config
metadata:
  name: my-app-config
spec:
  configName: "app-settings"
  namespace: "production"
  data:
    APP_ENV: "prod"
    LOG_LEVEL: "info"
    DATABASE_HOST: "postgres.production.svc"
```

## Key Patterns Checklist

- ✅ Accept `params = option("params") or {}`
- ✅ Extract spec: `_spec = _params?.oxr?.spec or {}`
- ✅ Provide fallbacks: `_field = _spec?.field or option("field") or "default"`
- ✅ Return `items = [...]` when `_params != {}`
- ✅ Return single resource when `_params == {}`
- ✅ Support both wrapped and unwrapped modes
- ✅ Include `providerConfigRef` for Crossplane Objects

## Quick Reference

| Mode | Input | Output | Use Case |
|------|-------|--------|----------|
| Direct | `-D field=value` | Single resource | Standalone, testing |
| Composition | `-D params='{...}'` | `items = [...]` | Crossplane Composition |
| Wrapped | `wrapInCrossplane=true` | Crossplane Object | Kubernetes provider |
| Unwrapped | `wrapInCrossplane=false` | Native K8s resource | Direct apply |

## Testing Your Module

```bash
# Test direct mode
kcl run main.k -D configName="test" -D 'data={"key": "value"}'

# Test composition mode
kcl run main.k -D params='{"oxr": {"spec": {"configName": "test", "data": {"key": "value"}}}}'

# Apply to cluster (direct)
kcl run main.k -D configName="test" | kubectl apply -f -

# Publish to registry
kcl mod push oci://ghcr.io/your-org/kcl-config:v1.0.0
```
