# Flux KCL Module

This KCL module creates a FluxInstance Custom Resource for installing and configuring Flux CD in a Kubernetes cluster. Optionally, it can also render Kubernetes Secrets for Git authentication and SOPS decryption.

## Features

- Configurable FluxInstance with all important parameters
- **Optional Kubernetes Secret rendering** for Git and SOPS
- SOPS integration for encrypted secrets
- Performance tuning for controllers
- Git repository synchronization
- Flexible component selection

## Installation

### From OCI Registry

```bash
# Add module from Stuttgart Things registry
kcl mod add oci://ghcr.io/stuttgart-things/kcl-flux-instance

# Or add with specific version
kcl mod add oci://ghcr.io/stuttgart-things/kcl-flux-instance --tag 0.1.0
```

### Local Development

```bash
# Clone and use locally
git clone https://github.com/stuttgart-things/kcl.git
cd kcl/kcl-flux-instance
```

## Usage

### Basic Installation with Default Values

```bash
kcl run kcl-flux-instance
```

### With Custom Values

```bash
kcl run kcl-flux-instance \
  -D name=my-flux \
  -D namespace=flux-system \
  -D version=2.4 \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  -D gitRef=refs/heads/main \
  -D gitPath=clusters/prod \
  -D gitPullSecret=my-git-token
```

### Performance Optimization

```bash
kcl run kcl-flux-instance \
  -D concurrent=20 \
  -D requeueDependency=3s
```

### Without SOPS Integration

```bash
kcl run kcl-flux-instance \
  -D sopsEnabled=false
```

### Cluster Configuration

```bash
kcl run kcl-flux-instance \
  -D multitenant=true \
  -D networkPolicy=true \
  -D domain=my-cluster.local
```

### Output to File

```bash
kcl run kcl-flux-instance \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  -D gitPath=clusters/staging \
  -o flux-instance.yaml
```

### Apply Directly to Cluster

```bash
kcl run kcl-flux-instance \
  -D gitUrl=https://github.com/my-org/my-repo.git | kubectl apply -f -
```

### Render with Kubernetes Secrets

Render FluxInstance along with Git and SOPS secrets in one command:

```bash
kcl run kcl-flux-instance \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  -D renderSecrets=true \
  -D gitUsername=my-github-user \
  -D gitPassword=ghp_myPersonalAccessToken \
  -D sopsAgeKey="AGE-SECRET-KEY-1..." \
  | kubectl apply -f -
```

### Only Git Secret (without SOPS)

```bash
kcl run kcl-flux-instance \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  -D renderSecrets=true \
  -D gitUsername=my-user \
  -D gitPassword=my-token \
  -D sopsEnabled=false \
  | kubectl apply -f -
```

### Only FluxInstance (no secrets)

```bash
# Secrets must be created manually
kcl run kcl-flux-instance \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  | kubectl apply -f -
```

## Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | `flux` | Name of the FluxInstance |
| `namespace` | string | `flux-system` | Namespace for Flux |
| `reconcileEvery` | string | `1h` | Reconciliation interval |
| `reconcileTimeout` | string | `5m` | Reconciliation timeout |
| `version` | string | `2.4` | Flux version |
| `registry` | string | `ghcr.io/fluxcd` | Container registry |
| `artifact` | string | `oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests` | OCI artifact |
| `components` | list | `[source-controller, kustomize-controller, ...]` | Flux components |
| `clusterType` | string | `kubernetes` | Cluster type |
| `multitenant` | bool | `false` | Multitenant mode |
| `networkPolicy` | bool | `true` | Enable NetworkPolicy |
| `domain` | string | `cluster.local` | Cluster domain |
| `sopsEnabled` | bool | `true` | Enable SOPS decryption |
| `sopsSecretName` | string | `sops-age` | Name of SOPS secret |
| `concurrent` | int | `10` | Number of concurrent reconciliations |
| `requeueDependency` | string | `5s` | Requeue interval for dependencies |
| `gitUrl` | string | `https://github.com/stuttgart-things/stuttgart-things.git` | Git repository URL |
| `gitRef` | string | `refs/heads/main` | Git branch/tag |
| `gitPath` | string | `clusters/vcluster/vso` | Path in repository |
| `gitPullSecret` | string | `git-token-auth` | Secret for Git authentication |
| `renderSecrets` | bool | `false` | **Render Kubernetes Secrets for Git and SOPS** |
| `gitUsername` | string | `""` | **Git username (only if renderSecrets=true)** |
| `gitPassword` | string | `""` | **Git password/token (only if renderSecrets=true)** |
| `sopsAgeKey` | string | `""` | **SOPS AGE private key (only if renderSecrets=true and sopsEnabled=true)** |

## Components

The following Flux components can be enabled:

- `source-controller` - Git repository and artifact management
- `kustomize-controller` - Kustomization reconciliation
- `helm-controller` - Helm release management
- `notification-controller` - Event notifications
- `image-reflector-controller` - Image scanning
- `image-automation-controller` - Image updates

## Examples

### Minimal Configuration for Dev Environment

```bash
kcl run kcl-flux-instance \
  -D name=flux-dev \
  -D namespace=flux-dev \
  -D gitUrl=https://github.com/my-org/dev-configs.git \
  -D gitPath=dev \
  -D sopsEnabled=false \
  -D networkPolicy=false
```

### Production Configuration with Full Control

```bash
kcl run kcl-flux-instance \
  -D name=flux-prod \
  -D namespace=flux-system \
  -D version=2.4 \
  -D gitUrl=https://github.com/my-org/prod-configs.git \
  -D gitRef=refs/heads/production \
  -D gitPath=clusters/prod/apps \
  -D gitPullSecret=prod-git-token \
  -D sopsEnabled=true \
  -D sopsSecretName=sops-age-prod \
  -D concurrent=20 \
  -D requeueDependency=3s \
  -D multitenant=true \
  -D networkPolicy=true
```

```
kcl --quiet main.k \
-D name=my-flux \
-D namespace=flux-system \
-D version=2.4 \
-D gitUrl=https://github.com/my-org/my-repo.git \
-D gitRef=refs/heads/main \
-D gitPath=clusters/prod \
-D gitPullSecret=my-git-token \
-D renderSecrets=true \
-D gitUsername=myuser \
-D gitPassword=ghp_xxxxxxxxxxxxx \
-D sopsAgeKey="AGE-SECRET-KEY-1XXXXXX" \
--format yaml | grep -v "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```


## Prerequisites

- KCL >= v0.11.2
- Kubernetes cluster with Flux Operator installed
- kubectl configured (for direct application)

## Installing Dependencies

```bash
cd kcl-flux-instance
kcl mod download
```
