# Flux KCL Module

This KCL module creates a FluxInstance Custom Resource for installing and configuring Flux CD in a Kubernetes cluster.

## Features

- Configurable FluxInstance with all important parameters
- SOPS integration for encrypted secrets
- Performance tuning for controllers
- Git repository synchronization
- Flexible component selection

## Usage

### Basic Installation with Default Values

```bash
kcl run /home/sthings/projects/kcl/flux/main.k
```

### With Custom Values

```bash
kcl run /home/sthings/projects/kcl/flux/main.k \
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
kcl run /home/sthings/projects/kcl/flux/main.k \
  -D concurrent=20 \
  -D requeueDependency=3s
```

### Without SOPS Integration

```bash
kcl run /home/sthings/projects/kcl/flux/main.k \
  -D sopsEnabled=false
```

### Cluster Configuration

```bash
kcl run /home/sthings/projects/kcl/flux/main.k \
  -D multitenant=true \
  -D networkPolicy=true \
  -D domain=my-cluster.local
```

### Output to File

```bash
kcl run /home/sthings/projects/kcl/flux/main.k \
  -D gitUrl=https://github.com/my-org/my-repo.git \
  -D gitPath=clusters/staging \
  -o flux-instance.yaml
```

### Apply Directly to Cluster

```bash
kcl run /home/sthings/projects/kcl/flux/main.k \
  -D gitUrl=https://github.com/my-org/my-repo.git | kubectl apply -f -
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
kcl run /home/sthings/projects/kcl/flux/main.k \
  -D name=flux-dev \
  -D namespace=flux-dev \
  -D gitUrl=https://github.com/my-org/dev-configs.git \
  -D gitPath=dev \
  -D sopsEnabled=false \
  -D networkPolicy=false
```

### Production Configuration with Full Control

```bash
kcl run /home/sthings/projects/kcl/flux/main.k \
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

## Prerequisites

- KCL >= v0.11.2
- Kubernetes cluster with Flux Operator installed
- kubectl configured (for direct application)

## Installing Dependencies

```bash
cd /home/sthings/projects/kcl/flux
kcl mod download
```
