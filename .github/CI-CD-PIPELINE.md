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

Published tags are **immutable**. Never republish a version that already exists
in the registry — consumers pin the tag, and a republish swaps the module source
under them without any visible signal. `publish-to-oci` skips a version that is
already published and `task push-module` refuses one; if a released artifact is
wrong, ship the fix as a new version.

## 📌 Consuming a published module

`kcl` takes the version from a `tag` query parameter or a `--tag` flag — **never
from a `:version` suffix in the URL path**. An inline suffix is parsed as part of
the repository name, the tag stays empty, and the reference silently resolves to
the *latest* published version:

```bash
# ❌ not a pin — resolves to whatever version was published last
kcl mod pull oci://ghcr.io/stuttgart-things/harvester-vm:0.2.0

# ✅ pinned
kcl mod pull oci://ghcr.io/stuttgart-things/harvester-vm --tag 0.2.0
kcl run oci://ghcr.io/stuttgart-things/harvester-vm --tag 0.2.0
```

The same holds for a `function-kcl` composition step, which resolves its source
through the same code — use the query form there:

```yaml
        # ❌ floats to the newest version
        source: oci://ghcr.io/stuttgart-things/harvester-vm:0.2.0
        # ✅ pinned
        source: oci://ghcr.io/stuttgart-things/harvester-vm?tag=0.2.0
```

…and in `kcl.mod` dependencies:

```toml
[dependencies]
harvester-vm = { oci = "oci://ghcr.io/stuttgart-things/harvester-vm", tag = "0.2.0", version = "0.2.0" }
```

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

### `GHCR_TOKEN` (optional, but needed for most packages)

`GITHUB_TOKEN` can only write to packages **linked** to this repository, and a
package only becomes linked by being published *from* it. Most module packages
here were first pushed from a workstation with a personal token, so they are
linked to nothing and the workflow cannot write them:

```
POST .../blobs/uploads/: 403 denied: permission_denied: write_package
```

Making the package public does not help — public grants anonymous *read*. There
is no API for the linkage either, so the alternative is clicking through
**Manage Actions access** on every package by hand.

Set two org (or repo) secrets to avoid that:

| secret | value |
|---|---|
| `GHCR_TOKEN` | a PAT with `write:packages` — the same kind of token `task push-module` already needs |
| `GHCR_USER` | the account that token belongs to (optional; defaults to `github.actor`) |

Both are optional. Without them the workflow falls back to `GITHUB_TOKEN` and
behaves exactly as before, so an unset secret only costs you the modules whose
packages are unlinked. The publish job prints which credential it is using.

A PAT with org-wide package write is broader than `GITHUB_TOKEN`, which is
minted per run and scoped to this repository. A GitHub App with
`packages: write`, or a fine-grained PAT limited to packages, is the tighter
option if that matters.

### Package visibility is still manual

Nothing here changes it: GitHub exposes no API for container package
visibility, so a new package stays private until someone flips it in
**Danger Zone → Change visibility**. The pipeline only reports the state.

## 📖 Additional Resources

- [KCL Documentation](https://kcl-lang.io/)
- [KCL Testing Guide](https://kcl-lang.io/docs/user_docs/guides/testing/)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Packages Documentation](https://docs.github.com/en/packages)
