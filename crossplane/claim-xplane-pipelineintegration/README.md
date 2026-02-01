# CLAIM-XPLANE-PIPELINEINTEGRATION

KCL schema for creating pipeline engine integrations via Crossplane.

## Templates

| Template | Description |
|----------|-------------|
| `tekton-basic` | Standard Tekton Pipeline setup with configurable components |
| `tekton-full` | Full Tekton setup with all components enabled (Pipeline, Triggers, Dashboard, Pruner) |
| `minimal` | Bare minimum required fields only |

## Usage

### Tekton Basic Template (default)

```bash
kcl run main.k
```

```bash
kcl run main.k -D templateName=tekton-basic
```

### Tekton Full Template

```bash
kcl run main.k -D templateName=tekton-full -D name=tekton-full-setup
```

### Minimal Template

```bash
kcl run main.k -D templateName=minimal -D name=simple-pipeline
```

### Custom Parameters

```bash
kcl run main.k -D name=my-pipeline -D version=0.77.5 -D enableTektonTriggers=true
```

```bash
kcl run main.k \
  -D name=production-tekton \
  -D targetClusterName=prod-cluster \
  -D targetClusterScope=Cluster \
  -D pipelineNamespace=tekton-pipelines \
  -D enableTektonPipeline=true \
  -D enableTektonTriggers=true \
  -D enableTektonDashboard=true
```

### Using OCI Registry

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-pipelineintegration --tag 0.1.0 \
  -D templateName=tekton-basic \
  -D name=my-tekton
```

## Available Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `templateName` | Template to use (tekton-basic, tekton-full, minimal) | `tekton-basic` |
| `name` | Resource name | `tekton-pipelines` |
| `namespace` | Kubernetes namespace | `default` |
| `engineType` | Pipeline engine type (tekton, argo-workflows, jenkins) | `tekton` |
| `targetClusterName` | Target cluster ProviderConfig name | `in-cluster` |
| `targetClusterScope` | Provider scope (Namespaced, Cluster) | `Cluster` |
| `tektonNamespace` | Namespace for Tekton operator | `tekton-operator` |
| `pipelineNamespace` | Namespace for Tekton pipelines | `tekton-pipelines` |
| `version` | Tekton chart version | `0.77.5` |
| `autoInstallComponents` | Auto-install Tekton components | `false` |
| `imagePullPolicy` | Image pull policy (Always, IfNotPresent, Never) | `Always` |
| `enableTektonPipeline` | Enable Tekton Pipeline | `true` |
| `enableTektonTriggers` | Enable Tekton Triggers | `false` |
| `enableTektonDashboard` | Enable Tekton Dashboard | `false` |
| `enableTektonPruner` | Enable Tekton Pruner | `false` |
| `chartRepository` | Tekton Helm chart repository | `oci://ghcr.io/stuttgart-things/tekton` |

## Supported Pipeline Engines

Currently, the following engines are supported:

| Engine | Status | Description |
|--------|--------|-------------|
| `tekton` | Supported | Cloud-native CI/CD with Tekton Pipelines |
| `argo-workflows` | Planned | Kubernetes-native workflow engine |
| `jenkins` | Planned | Traditional CI/CD server |
