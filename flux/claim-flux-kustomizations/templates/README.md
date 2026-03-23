# Claim Templates

ClaimTemplate definitions for rendering Flux Kustomization resources via the [claims CLI](https://github.com/stuttgart-things/claims) and [claim-machinery API](https://github.com/stuttgart-things/claim-machinery-api).

## Prerequisites

- `claims` CLI installed
- claim-machinery API running (default: `http://localhost:8080`)

```bash
export CLAIM_API_URL=http://localhost:8080
```

## Available Templates

### Sources

| Template | Description | Default dependsOn |
|---|---|---|
| `flux-gitrepository` | Flux GitRepository source | - |

### Base Templates

| Template | Description | Default dependsOn |
|---|---|---|
| `flux-kustomization-gitops` | Generic GitOps Flux Kustomization | - |
| `flux-kustomization-infrastructure` | Infrastructure Kustomization with wait, health checks, dependencies | - |

### Infrastructure

| Template | Description | Default dependsOn |
|---|---|---|
| `flux-kustomization-cert-manager-install` | Cert-manager deployment with CRDs | - |
| `flux-kustomization-cert-manager-selfsigned` | Self-signed certificate issuer (Vault PKI) | `cert-manager-install` |
| `flux-kustomization-trust-manager` | CA certificate distribution via trust-manager | `cert-manager-install` |
| `flux-kustomization-openebs` | OpenEBS local storage | - |
| `flux-kustomization-nfs-csi` | NFS CSI storage driver | - |
| `flux-kustomization-cilium-lb` | Cilium LoadBalancer with Clusterbook IPAM | - |
| `flux-kustomization-cilium-gateway` | Cilium Gateway API with TLS | - |

### Crossplane

| Template | Description | Default dependsOn |
|---|---|---|
| `flux-kustomization-crossplane-install` | Crossplane core with Helm, K8s, OpenTofu providers | - |
| `flux-kustomization-crossplane-functions` | Crossplane Functions (auto-ready, go-templating, kcl, patch-and-transform) | `crossplane-install` |
| `flux-kustomization-crossplane-configs` | Crossplane Configurations (cloud-config, volume-claim, storage-platform, ansible-run, pipeline-integration, harvester-vm) | `crossplane-install`, `crossplane-functions` |

### Applications

| Template | Description | Default dependsOn |
|---|---|---|
| `flux-kustomization-vault` | HashiCorp Vault deployment | - |
| `flux-kustomization-vault-autounseal` | Vault auto-unseal mechanism | - |
| `flux-kustomization-vault-httproute` | Vault HTTP Gateway route | - |
| `flux-kustomization-flux-web` | Flux dashboard UI | - |
| `flux-kustomization-headlamp` | Kubernetes dashboard | - |
| `flux-kustomization-prometheus` | Prometheus monitoring stack | - |
| `flux-kustomization-uptime-kuma` | Uptime monitoring | - |
| `flux-kustomization-clusterbook-app` | Clusterbook app with optional PowerDNS | - |
| `flux-kustomization-minio` | MinIO object storage with cert-manager TLS (includes SOPS secret) | - |
| `flux-kustomization-minio-httproute` | MinIO Gateway API HTTPRoutes (console + API) | `minio` |

## Usage Examples

### Render a single template

```bash
claims render --non-interactive \
  -t flux-kustomization-crossplane-install \
  -p sourceRefName=flux-apps \
  -p crossplaneVersion=2.2.0 \
  --dry-run
```

### Render with dependencies

```bash
claims render --non-interactive \
  -t flux-kustomization-crossplane-functions \
  -p sourceRefName=flux-apps \
  -p dependsOnNames=crossplane-install \
  --dry-run
```

### Render with custom substitutions

```bash
claims render --non-interactive \
  -t flux-kustomization-gitops \
  -p name=my-app \
  -p sourceRefName=flux-apps \
  -p path="./apps/my-app" \
  -p substitute="APP_VERSION=v1.0.0,APP_NAMESPACE=production" \
  --dry-run
```

### Render with remote cluster kubeconfig

```bash
claims render --non-interactive \
  -t flux-kustomization-infrastructure \
  -p name=cert-manager \
  -p sourceRefName=flux-infra \
  -p path="./infra/cert-manager" \
  -p kubeConfigSecretRef=remote-cluster-kubeconfig \
  --dry-run
```

### Render multiple templates from file

```bash
claims render --non-interactive -f gitrepos.yaml -o ./out --single-file
```

### Write output to directory

```bash
claims render --non-interactive \
  -t flux-kustomization-crossplane-install \
  -p sourceRefName=flux-apps \
  -o ./output/ \
  --filename-pattern "{{.name}}.yaml"
```

## Common Flags

| Flag | Description |
|---|---|
| `-t` | Template name |
| `-p` | Parameter (key=value, repeatable) |
| `--non-interactive` | Skip interactive prompts |
| `--dry-run` | Print output without writing files |
| `--skip-secrets` | Skip secret generation |
| `-o` | Output directory (default: `.`) |
| `-f` | Parameters from YAML/JSON file |
| `--filename-pattern` | Output filename pattern (Go template) |
| `--single-file` | Combine all output into a single file |

## OCI Source

All templates render KCL modules from:

```
oci://ghcr.io/stuttgart-things/claim-flux-kustomizations
```
