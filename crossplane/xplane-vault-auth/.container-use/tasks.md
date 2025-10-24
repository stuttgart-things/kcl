# xplane-vault-auth Development Tasks

## Module Development Workflow

### Core Development Tasks

#### 1. Module Structure Setup
```bash
# Create basic module structure
mkdir -p xplane-vault-auth/{examples,tests,.container-use}

# Initialize KCL module
kcl mod init xplane-vault-auth
```

#### 2. Schema Development
```bash
# Define temporary schemas (until OCI dependency available)
# Edit main.k with TerraformWorkspace and K8sAuth schemas

# Validate schema syntax
kcl fmt main.k --check
```

#### 3. Function Implementation
```bash
# Implement core functions:
# - generateServiceAccountTerraform: HCL generation
# - vaultK8sAuth: Main authentication setup
# - simpleVaultK8sAuth: Simplified API
# - advancedVaultK8sAuth: Custom configuration

# Test function logic
kcl run tests/test_main.k
```

#### 4. Testing and Validation
```bash
# Run comprehensive tests
kcl run tests/test_main.k

# Validate examples
kcl run examples/simple-auth.k

# Check generated Terraform syntax
kcl run examples/simple-auth.k | grep -A 50 "resource"
```

### CRD Integration Tasks (Future)

#### 5. Migrate to OCI Dependencies
```bash
# When crossplane-provider-terraform is published to OCI
kcl mod add oci://ghcr.io/stuttgart-things/crossplane-provider-terraform

# Update imports in main.k
# Replace inline schemas with imported ones

# Test migration
kcl run tests/test_main.k
```

#### 6. Enhanced Type Safety
```bash
# Validate against upstream CRD schemas
kcl import -m crd crossplane-terraform-provider.yaml

# Compare generated schemas with inline versions
diff generated-schemas.k main.k
```

### Development Environment Tasks

#### 7. Container-Use Integration
```bash
# Create development environment
container-use create --title "vault auth development"

# Install dependencies
apt-get update && apt-get install -y kcl

# Run development workflow
cd xplane-vault-auth && kcl run tests/test_main.k
```

#### 8. Documentation Tasks
```bash
# Generate API documentation
kcl doc main.k > docs/api.md

# Validate examples in README
grep -o '```kcl[^`]*```' README.md | kcl run --stdin

# Check links and formatting
lychee README.md
```

### Quality Assurance Tasks

#### 9. Code Quality
```bash
# Format code
kcl fmt main.k examples/ tests/

# Lint for best practices
kcl lint main.k

# Check for unused imports
kcl run --unused-imports main.k
```

#### 10. Security Validation
```bash
# Check for sensitive data exposure
grep -r "password\|token\|secret" . --exclude-dir=.git

# Validate RBAC configurations
kcl run examples/simple-auth.k | grep -A 10 "ClusterRole"

# Test namespace isolation
kcl run tests/test_main.k | grep namespace
```

### Integration Testing Tasks

#### 11. End-to-End Testing
```bash
# Test with real Crossplane cluster
kubectl apply -f <(kcl run examples/simple-auth.k)

# Verify resource creation
kubectl get workspace -A

# Check Terraform execution
kubectl logs -f deployment/crossplane-terraform-provider
```

#### 12. Vault Integration Testing
```bash
# Test authentication flow
vault auth -method=kubernetes role=test-app jwt=$SERVICE_ACCOUNT_JWT

# Verify token review permissions
kubectl auth can-i create tokenreview --as=system:serviceaccount:default:test-app-vault-auth
```

### Publishing and Distribution Tasks

#### 13. Module Publishing
```bash
# Prepare for OCI publishing
kcl mod publish oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.0

# Tag release
git tag v0.1.0 && git push origin v0.1.0

# Update registry metadata
kcl mod update-registry
```

#### 14. Documentation Publishing
```bash
# Generate documentation site
kcl doc --output-format html main.k

# Update module registry
curl -X POST registry.kcl.dev/api/modules \
  -d '{"name": "xplane-vault-auth", "version": "0.1.0"}'
```

### Maintenance Tasks

#### 15. Dependency Updates
```bash
# Update to latest KCL version
kcl mod update

# Check for security updates
kcl mod audit

# Update Terraform provider schemas
kcl import -m crd latest-crossplane-terraform-crds.yaml
```

#### 16. Compatibility Testing
```bash
# Test with different KCL versions
for version in 0.10.0 0.11.0; do
  kcl-$version run tests/test_main.k
done

# Test with different Crossplane versions
for version in 1.14 1.15; do
  kubectl apply -f crossplane-$version.yaml
  kcl run examples/simple-auth.k | kubectl apply -f -
done
```

### Monitoring and Observability Tasks

#### 17. Performance Monitoring
```bash
# Measure compilation time
time kcl run tests/test_main.k

# Check memory usage
kcl run --memory-profile tests/test_main.k

# Analyze generated resource size
kcl run examples/simple-auth.k | wc -l
```

#### 18. Usage Analytics
```bash
# Track module usage
grep "import.*xplane-vault-auth" $(find . -name "*.k")

# Monitor OCI registry downloads
curl registry.kcl.dev/api/modules/xplane-vault-auth/stats

# Collect user feedback
gh issue list --repo stuttgart-things/xplane-vault-auth
```

## Automation Workflows

### CI/CD Pipeline Tasks
```yaml
# .github/workflows/test.yml
- name: Test KCL Module
  run: |
    kcl fmt --check main.k
    kcl run tests/test_main.k
    kcl run examples/simple-auth.k

- name: Validate Examples
  run: |
    for example in examples/*.k; do
      kcl run "$example"
    done

- name: Security Scan
  run: |
    kcl lint main.k
    semgrep --config=auto .
```

### Release Automation
```bash
# Automated release workflow
git tag v0.1.1
github-release create \
  --tag v0.1.1 \
  --name "xplane-vault-auth v0.1.1" \
  --description "$(git log --oneline v0.1.0..v0.1.1)"
```

## Stuttgart-Things Integration

### Standards Compliance
- ✅ Container-use development environment
- ✅ Comprehensive decision documentation
- ✅ Test-driven development
- ✅ Example-driven documentation
- ✅ Security-first design

### Repository Structure
```
xplane-vault-auth/
├── main.k              # Core module
├── kcl.mod            # Module definition
├── README.md          # Documentation
├── examples/          # Usage examples
├── tests/             # Test suite
└── .container-use/    # Development environment
    ├── decisions.md   # Architecture decisions
    └── tasks.md       # Development tasks
```
