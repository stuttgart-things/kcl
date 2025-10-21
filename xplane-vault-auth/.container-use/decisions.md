# Stuttgart-Things Development Decisions

## Project Overview

**Project**: xplane-vault-auth
**Purpose**: KCL module for Vault Kubernetes authentication using Terraform provider through Crossplane
**Date**: December 2024

## Architecture Decisions

### 1. Terraform Provider Integration

**Decision**: Use Crossplane Terraform provider with inline HCL code generation
**Reasoning**:
- Provides full Terraform functionality within Crossplane
- Enables ServiceAccount and RBAC management
- Maintains infrastructure-as-code principles
- Supports complex authentication workflows

**Alternatives Considered**:
- Native Kubernetes provider: Limited RBAC capabilities
- Direct Kubernetes manifests: Not infrastructure-as-code approach
- Helm charts: Less flexible for dynamic configurations

### 2. Schema Design

**Decision**: Implement temporary inline schemas until crossplane-provider-terraform OCI publication
**Reasoning**:
- Unblocks development while dependency is being published
- Maintains full type safety and validation
- Easy migration path when OCI dependency becomes available
- Follows established patterns from other modules

**Migration Path**:
```kcl
# Current (temporary)
schema TerraformWorkspace: { ... }

# Future (when OCI available)
import crossplane_provider_terraform.v1beta1.tf_crossplane_io_v1beta1_workspace as terraform
```

### 3. Authentication Flow

**Decision**: Generate ServiceAccount, ClusterRoleBinding, and Secret resources via Terraform
**Reasoning**:
- Follows Kubernetes authentication best practices
- Supports both new (projected tokens) and legacy (secret-based) workflows
- Provides necessary RBAC permissions for token review
- Outputs required data for Vault configuration

**Components**:
- ServiceAccount: Identity for Vault authentication
- ClusterRoleBinding: system:auth-delegator permissions
- Secret: Token access (backward compatibility)
- Outputs: JWT token and CA certificate

### 4. API Design Philosophy

**Decision**: Provide both simple and advanced configuration options
**Reasoning**:
- Simple API: Quick start for common use cases
- Advanced API: Full control for complex scenarios
- Custom Terraform: Override capability for edge cases
- Consistent with Stuttgart-Things module patterns

**API Levels**:
```kcl
# Level 1: Simple
simpleVaultK8sAuth(name, clusterName, vaultAddr)

# Level 2: Advanced
vaultK8sAuth(K8sAuth{...})

# Level 3: Custom
advancedVaultK8sAuth(auth, customTerraformCode)
```

### 5. HCL Generation Strategy

**Decision**: Template-based Terraform HCL generation with parameter substitution
**Reasoning**:
- Maintains readability and maintainability
- Supports dynamic content generation
- Enables validation and testing
- Follows Terraform best practices

**Template Structure**:
- Resource definitions with variable interpolation
- Outputs for integration with Vault configuration
- Metadata preservation for traceability

## CRD Integration Workflow

### Established Pattern (from crossplane-provider-terraform)

1. **CRD Import**: `kcl import -m crd crossplane-provider-terraform-crds.yaml`
2. **Schema Generation**: Automatic KCL schema generation from CRD
3. **Type Safety**: Full validation and IntelliSense support
4. **OCI Publishing**: Module distribution via container registry

### Current Workaround

1. **Inline Schemas**: Temporary schema definitions in main.k
2. **Manual Type Definitions**: Based on upstream CRD analysis
3. **Migration Ready**: Easy switch when OCI dependency available

## Testing Strategy

### Unit Tests
- Schema validation
- Function correctness
- Terraform code generation
- Output format verification

### Integration Tests
- End-to-end authentication flow
- Crossplane resource creation
- Vault authentication validation

### Example Validation
- Simple authentication scenarios
- Advanced configuration options
- Custom Terraform code integration

## Future Considerations

### 1. OCI Migration
**When**: crossplane-provider-terraform published to OCI registry
**Action**: Replace inline schemas with import statements
**Impact**: Improved type safety and automatic updates

### 2. Enhanced Authentication
**Consideration**: Support for additional Vault auth methods
**Examples**: AWS IAM, Azure AD, OIDC integration
**Implementation**: Additional schemas and Terraform generators

### 3. Multi-Cluster Support
**Consideration**: Cross-cluster authentication scenarios
**Implementation**: Extended configuration schema
**Use Cases**: Federated authentication, multi-region setups

### 4. Vault Policy Integration
**Consideration**: Automatic policy creation for authenticated identities
**Implementation**: Additional Terraform resources
**Benefits**: Complete end-to-end authentication setup

## Compliance and Standards

### Stuttgart-Things Standards
- ✅ Container-use integration
- ✅ Comprehensive documentation
- ✅ Test coverage
- ✅ Example configurations
- ✅ Decision documentation

### KCL Best Practices
- ✅ Schema-driven design
- ✅ Function composition
- ✅ Type safety
- ✅ Clear naming conventions
- ✅ Modular architecture

### Security Considerations
- ✅ RBAC principle of least privilege
- ✅ Token security (sensitive outputs)
- ✅ Namespace isolation
- ✅ Audit trail via resource metadata