# Kubernetes Secret Rendering

The `kcl-flux-instance` module can optionally render Kubernetes Secrets for Git authentication and SOPS decryption alongside the FluxInstance Custom Resource.

## Overview

By default, the module only renders the FluxInstance CR. You need to create the secrets manually:

```bash
# Git authentication secret
kubectl create secret generic git-token-auth \
  --namespace flux-system \
  --from-literal=username=my-user \
  --from-literal=password=my-token

# SOPS decryption secret  
kubectl create secret generic sops-age \
  --namespace flux-system \
  --from-literal=age.agekey="AGE-SECRET-KEY-1..."
```

## Automatic Secret Rendering

Enable secret rendering by setting `renderSecrets=true`:

### Render FluxInstance + Git Secret + SOPS Secret

```bash
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  -D renderSecrets=true \
  -D gitUsername=my-github-user \
  -D gitPassword=ghp_myPersonalAccessToken \
  -D sopsAgeKey="AGE-SECRET-KEY-1QYG..." \
  | kubectl apply -f -
```

This will create:
1. FluxInstance CR named `flux` in `flux-system` namespace
2. Secret `git-token-auth` with Git credentials
3. Secret `sops-age` with SOPS AGE private key

### Render FluxInstance + Git Secret Only

```bash
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  -D renderSecrets=true \
  -D gitUsername=my-user \
  -D gitPassword=my-token \
  -D sopsEnabled=false \
  | kubectl apply -f -
```

This will create:
1. FluxInstance CR (without SOPS patch)
2. Secret `git-token-auth` with Git credentials

### Render Only FluxInstance (Default)

```bash
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  | kubectl apply -f -
```

This will create:
1. FluxInstance CR only
2. You must create secrets manually

## Secret Structure

### Git Authentication Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-token-auth  # Configurable via gitPullSecret parameter
  namespace: flux-system
type: Opaque
stringData:
  username: <gitUsername>
  password: <gitPassword>
```

### SOPS Decryption Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sops-age  # Configurable via sopsSecretName parameter
  namespace: flux-system
type: Opaque
stringData:
  age.agekey: <sopsAgeKey>
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `renderSecrets` | No | `false` | Enable Kubernetes Secret rendering |
| `gitUsername` | If `renderSecrets=true` | `""` | Git username for authentication |
| `gitPassword` | If `renderSecrets=true` | `""` | Git password/token for authentication |
| `sopsAgeKey` | If `renderSecrets=true` and `sopsEnabled=true` | `""` | SOPS AGE private key |
| `gitPullSecret` | No | `git-token-auth` | Name of Git authentication secret |
| `sopsSecretName` | No | `sops-age` | Name of SOPS decryption secret |

## Security Considerations

⚠️ **Important Security Notes:**

1. **Avoid command-line secrets in production**
   - Command-line arguments may be visible in process lists
   - Use environment variables or files instead

2. **Use secure secret management**
   ```bash
   # Better: Use environment variables
   export GIT_PASSWORD="ghp_..."
   export SOPS_AGE_KEY="AGE-SECRET-KEY-1..."
   
   kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
     -D gitUrl=https://github.com/my-org/my-repo.git \
     -D renderSecrets=true \
     -D gitUsername=my-user \
     -D gitPassword="${GIT_PASSWORD}" \
     -D sopsAgeKey="${SOPS_AGE_KEY}" \
     | kubectl apply -f -
   ```

3. **Alternative: Render to file, review, then apply**
   ```bash
   # Render to file
   kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
     -D gitUrl=https://github.com/my-org/my-repo.git \
     -D renderSecrets=true \
     -D gitUsername=my-user \
     -D gitPassword="${GIT_PASSWORD}" \
     -D sopsAgeKey="${SOPS_AGE_KEY}" \
     > flux-with-secrets.yaml
   
   # Review the file
   cat flux-with-secrets.yaml
   
   # Apply
   kubectl apply -f flux-with-secrets.yaml
   
   # Clean up
   shred -u flux-with-secrets.yaml
   ```

4. **Production Recommendation**
   - Create secrets manually using secure methods (Vault, SOPS, sealed-secrets)
   - Use `renderSecrets=false` (default) in production
   - Only use secret rendering for development/testing

## Interactive Usage with Taskfile

The interactive taskfile at `platform-engineering-showcase/taskfiles/flux.yaml` provides secure prompts:

```bash
task --taskfile taskfiles/flux.yaml render
```

This will:
1. Ask if you want to render secrets
2. Use `gum input --password` for sensitive values (hidden input)
3. Only prompt for secrets if you choose "Render Secrets: true"

## Examples

### Development Setup (All-in-One)

```bash
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D gitUrl=https://github.com/my-org/dev-configs.git \
  -D gitPath=clusters/dev \
  -D renderSecrets=true \
  -D gitUsername=dev-user \
  -D gitPassword=dev-token \
  -D sopsEnabled=false \
  | kubectl apply -f -
```

### Staging Setup (Git + SOPS)

```bash
export GIT_TOKEN=$(cat ~/.secrets/git-token)
export SOPS_KEY=$(cat ~/.secrets/sops-age-key)

kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D gitUrl=https://github.com/my-org/staging-configs.git \
  -D gitPath=clusters/staging \
  -D renderSecrets=true \
  -D gitUsername=staging-bot \
  -D gitPassword="${GIT_TOKEN}" \
  -D sopsAgeKey="${SOPS_KEY}" \
  | kubectl apply -f -
```

### Production Setup (Manual Secrets)

```bash
# Create secrets securely (outside of KCL)
kubectl create secret generic git-token-auth \
  --namespace flux-system \
  --from-file=username=<(echo -n "prod-user") \
  --from-file=password=<(vault kv get -field=token secret/prod/git)

kubectl create secret generic sops-age \
  --namespace flux-system \
  --from-file=age.agekey=<(vault kv get -field=key secret/prod/sops)

# Render only FluxInstance
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D gitUrl=https://github.com/my-org/prod-configs.git \
  -D gitPath=clusters/production \
  | kubectl apply -f -
```

## Troubleshooting

### Secrets are not being rendered

Check that all required parameters are provided:

```bash
# Missing credentials - no secret rendered
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D renderSecrets=true \
  # ❌ Missing gitUsername and gitPassword - Git secret will NOT be rendered

# Correct usage
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D renderSecrets=true \
  -D gitUsername=user \
  -D gitPassword=token \
  # ✅ Git secret WILL be rendered
```

### SOPS secret not rendered

Verify that both `sopsEnabled=true` and `sopsAgeKey` are provided:

```bash
# This will NOT render SOPS secret
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D renderSecrets=true \
  -D sopsEnabled=true \
  # ❌ Missing sopsAgeKey

# This WILL render SOPS secret
kcl run oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.2.0 \
  -D renderSecrets=true \
  -D sopsEnabled=true \
  -D sopsAgeKey="AGE-SECRET-KEY-1..." \
  # ✅ SOPS secret rendered
```

## See Also

- [Main README](README.md) - General module documentation
- [Flux CD Documentation](https://fluxcd.io/flux/guides/mozilla-sops/) - SOPS integration guide
- [AGE Encryption](https://github.com/FiloSottile/age) - Age encryption tool
