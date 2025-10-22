# KCL Module CI/CD Pipeline

This repository includes an automated CI/CD pipeline for KCL modules that handles linting, testing, and publishing to the GitHub Container Registry (GHCR).

## 🚀 Features

- **Automated Linting**: Runs `kcl lint` on all changed modules
- **Code Formatting**: Validates code formatting with `kcl fmt`
- **Automated Testing**: Executes test suites with `kcl test`
- **Module Validation**: Checks module structure and semantic versioning
- **OCI Publishing**: Automatically publishes to `ghcr.io/stuttgart-things/<module-name>`
- **Version Detection**: Skips publishing if version already exists
- **Multi-Module Support**: Handles multiple modules in a single push

## 📋 Pipeline Stages

### 1. Detect Changed Modules
- Identifies modified KCL modules from git diff
- Supports modules with prefixes: `kcl-*`, `xplane-*`, `crossplane-*`
- Creates a matrix for parallel execution

### 2. Lint and Test
For each changed module:
- **Format Check**: Validates code formatting
- **Lint**: Runs KCL linter to check for code issues
- **Tests**: Executes all test files matching `*_test.k`
- **Execution Test**: Runs the module with default values
- **Structure Validation**: Checks for required files and valid semantic versioning

### 3. Publish to OCI
On `main` branch pushes only:
- **Version Check**: Verifies if version exists in registry
- **OCI Push**: Publishes module to GHCR
- **Package Visibility**: Provides instructions for making package public
- **Release Summary**: Creates detailed summary in GitHub Actions

## 📁 Module Structure Requirements

Every KCL module must have:

```
<module-name>/
├── kcl.mod              # Module definition with name and version
├── main.k               # Main module code
├── README.md            # Documentation
├── tests/
│   └── main_test.k      # Test files (*_test.k pattern)
└── kcl.mod.lock         # Dependency lock file (auto-generated)
```

## 🧪 Writing Tests

Create test files in the `tests/` directory with the `*_test.k` naming pattern:

```kcl
# tests/main_test.k
import ..main as mymodule

test_basic_functionality = lambda {
    """Test basic module functionality"""
    result = mymodule.items
    
    assert len(result) > 0, "Should generate resources"
    assert result[0].kind == "MyResource", "Should have correct kind"
    
    print("✅ test_basic_functionality passed")
}

# Run tests
test_basic_functionality()
```

Run tests locally:
```bash
kcl test ./...
```

## 🔍 Linting and Formatting

### Lint your code:
```bash
kcl lint .
```

### Format your code:
```bash
kcl fmt ./...
```

### Check formatting without changes:
```bash
kcl fmt .
git diff --exit-code  # Fails if there are changes
```

## 📦 Publishing Flow

### 1. Development
```bash
# Make changes to your module
cd <module-name>

# Run tests
kcl test ./...

# Lint code
kcl lint .

# Format code
kcl fmt ./...
```

### 2. Version Bump
Update version in `kcl.mod`:
```toml
[package]
name = "my-module"
edition = "v0.11.2"
version = "0.2.0"  # Bump version here
```

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features (backwards compatible)
- **PATCH** (0.0.1): Bug fixes

### 3. Commit and Push
```bash
git add .
git commit -m "feat(my-module): add new feature"
git push origin main
```

### 4. Automated Pipeline
The pipeline will:
1. ✅ Detect your module changes
2. ✅ Run lint, format check, and tests
3. ✅ Check if version exists
4. ✅ Publish to OCI registry (if new version)
5. ✅ Create release summary

### 5. Make Package Public
If this is the first version of a new module:

1. Go to: `https://github.com/orgs/stuttgart-things/packages/container/<module-name>/settings`
2. Scroll to **"Danger Zone"**
3. Click **"Change visibility"** → Select **"Public"**
4. Confirm the change

## 🎯 Conventional Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:

```bash
# Features
git commit -m "feat(kcl-flux-instance): add SOPS support"

# Bug fixes
git commit -m "fix(xplane-vault): correct boolean handling"

# Documentation
git commit -m "docs(crossplane-terraform): update README"

# Breaking changes
git commit -m "feat(kcl-flux-instance): rename config parameter

BREAKING CHANGE: Parameter 'name' renamed to 'configName'"
```

## 🔄 Pipeline Triggers

The pipeline runs on:
- **Push to main**: Full lint, test, and publish
- **Pull Request**: Lint and test only (no publishing)

Triggered by changes in:
- `kcl-*/` directories
- `xplane-*/` directories
- `crossplane-*/` directories

## 📊 GitHub Actions Summary

After each run, check the Actions Summary for:
- ✅ Test results
- 📦 Published modules with installation instructions
- ⚠️  Post-publication steps (if needed)
- ⏭️  Skipped publications (version exists)

## 🛠️ Local Development

### Install KCL
```bash
curl -fsSL https://kcl-lang.io/script/install-cli.sh | bash
```

### Test Module Locally
```bash
cd <module-name>

# Run module
kcl run .

# With options
kcl run . -D name=test -D namespace=testing

# Run tests
kcl test ./...

# Lint
kcl lint .

# Format
kcl fmt ./...
```

### Test OCI Publishing Locally
```bash
# Login to GHCR
echo $GITHUB_TOKEN | kcl registry login ghcr.io -u <username> --password-stdin

# Push module
kcl mod push oci://ghcr.io/stuttgart-things/<module-name>
```

## 📚 Examples

### Example 1: New Module
```bash
# Create module structure
mkdir kcl-my-new-module
cd kcl-my-new-module

# Initialize
kcl mod init

# Edit kcl.mod
cat > kcl.mod << EOF
[package]
name = "kcl-my-new-module"
edition = "v0.11.2"
version = "0.1.0"
EOF

# Create main.k
# Create tests/main_test.k
# Create README.md

# Test locally
kcl test ./...
kcl lint .

# Commit and push
git add .
git commit -m "feat(kcl-my-new-module): initial release"
git push origin main
```

### Example 2: Update Existing Module
```bash
cd kcl-flux-instance

# Make changes
# Update tests

# Bump version in kcl.mod (0.1.0 -> 0.2.0)

# Test
kcl test ./...

# Commit
git commit -m "feat(kcl-flux-instance): add new configuration option"
git push origin main
```

## 🐛 Troubleshooting

### Tests Failing?
```bash
# Run tests locally with verbose output
kcl test ./... --fail-fast

# Check specific test
kcl test ./... --run test_name
```

### Lint Errors?
```bash
# Check lint output
kcl lint .

# Auto-format code
kcl fmt ./...
```

### Version Already Exists?
- Bump version in `kcl.mod`
- Follow semantic versioning
- Commit and push again

### Package Not Public?
- Manually change visibility in GitHub settings
- Only needed once per new module

## 🔐 Permissions

The pipeline requires:
- `contents: read` - Read repository code
- `packages: write` - Publish to GHCR
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

## 📖 Additional Resources

- [KCL Documentation](https://kcl-lang.io/)
- [KCL Testing Guide](https://kcl-lang.io/docs/user_docs/guides/testing/)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Packages Documentation](https://docs.github.com/en/packages)
