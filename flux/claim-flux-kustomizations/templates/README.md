# Claim Templates

ClaimTemplate definitions for rendering Flux Kustomization resources via the [claims CLI](https://github.com/stuttgart-things/claims) and [claim-machinery API](https://github.com/stuttgart-things/claim-machinery-api).

## Prerequisites

- `claims` CLI installed
- claim-machinery API running (default: `http://localhost:8080`)

```bash
export CLAIM_API_URL=http://localhost:8080
```

```bash
claims render --non-interactive -f gitrepos.yaml -o ./out --single-file
```

## Available Templates

| Template | Description |
|---|---|
| `clusterbook` | Clusterbook app deployment with optional PowerDNS and NetworkConfig |
| `cilium-clusterbook` | Cilium LoadBalancer with IP reservation from Clusterbook |
| `kustomization-gitops` | Generic GitOps Flux Kustomization |
| `kustomization-infrastructure` | Infrastructure Kustomization with wait, health checks, dependencies |
| `kustomization-crossplane` | Crossplane deployment with Terraform, Helm, and K8s providers |

## Usage Examples

### Clusterbook (no PDNS, no NetworkConfig)

```bash
claims render --non-interactive \
  -t clusterbook \
  -p PDNS_ENABLED=false \
  -p networkConfigName="" \
  --skip-secrets \
  --dry-run
```

### Clusterbook (with PDNS enabled)

```bash
claims render --non-interactive \
  -t clusterbook \
  -p PDNS_ENABLED=true \
  -p PDNS_URL=https://pdns.sthings-vsphere.labul.sva.de \
  -p PDNS_ZONE=sthings-vsphere.labul.sva.de \
  -p networkConfigName="10.31.102" \
  -o output
```

### Clusterbook (with NetworkConfig)

Complex values like `networks` must be passed via a params file (`-f`):

```bash
cat <<'EOF' > /tmp/params.yaml
PDNS_ENABLED: "false"
networkConfigName: clusterbook-networks
networks:
  "10.31.101":
    - "5:ASSIGNED:rancher-mgmt"
    - "6"
    - "7"
  "10.31.103":
    - "3"
    - "4:ASSIGNED:sandiego"
EOF

claims render --non-interactive \
  -t clusterbook \
  -f /tmp/params.yaml \
  --skip-secrets \
  --dry-run
```

### Clusterbook (custom versions and domain)

```bash
claims render --non-interactive \
  -t clusterbook \
  -p CLUSTERBOOK_VERSION=v1.20.1 \
  -p CLUSTERBOOK_HOSTNAME=myapp \
  -p DOMAIN=myapp.example.com \
  -p GATEWAY_NAME=my-gateway \
  -p GATEWAY_NAMESPACE=ingress \
  -p PDNS_ENABLED=false \
  -p networkConfigName="" \
  --skip-secrets \
  -o output
```

### Cilium LoadBalancer with Clusterbook IPAM

```bash
claims render --non-interactive \
  -t cilium-clusterbook \
  -p clusterName=testcluster \
  -p networkKey=10.31.103 \
  -p registerDns=false \
  -o output
```

### GitOps Kustomization

```bash
claims render --non-interactive \
  -t kustomization-gitops \
  -p name=my-app \
  -p sourceRefName=flux-apps \
  -p path="./apps/my-app" \
  -p namespace=flux-system \
  --dry-run
```

### GitOps with post-build substitutions

```bash
claims render --non-interactive \
  -t kustomization-gitops \
  -p name=my-app \
  -p sourceRefName=flux-apps \
  -p path="./apps/my-app" \
  -p substitute="APP_VERSION=v1.0.0,APP_NAMESPACE=production" \
  --dry-run
```

### GitOps with dependencies

```bash
claims render --non-interactive \
  -t kustomization-gitops \
  -p name=my-app \
  -p sourceRefName=flux-apps \
  -p path="./apps/my-app" \
  -p dependsOnNames="cert-manager,ingress-nginx" \
  --dry-run
```

### Infrastructure Kustomization

```bash
claims render --non-interactive \
  -t kustomization-infrastructure \
  -p name=cert-manager \
  -p sourceRefName=flux-infra \
  -p path="./infra/cert-manager" \
  --dry-run
```

### Infrastructure with dependencies and remote cluster

```bash
claims render --non-interactive \
  -t kustomization-infrastructure \
  -p name=ingress-nginx \
  -p sourceRefName=flux-infra \
  -p path="./infra/ingress-nginx" \
  -p dependsOnNames="cert-manager" \
  -p kubeConfigSecretRef=remote-cluster-kubeconfig \
  --dry-run
```

### Crossplane deployment

```bash
claims render --non-interactive \
  -t kustomization-crossplane \
  -p name=crossplane \
  -p sourceRefName=flux-apps \
  -p path="./cicd/crossplane" \
  -p crossplaneVersion=2.1.3 \
  -p terraformProviderVersion=v1.0.5 \
  --dry-run
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
| `--combine-secrets` | Combine secrets in same output file |

## Writing output to file

```bash
claims render --non-interactive \
  -t clusterbook \
  -p PDNS_ENABLED=false \
  -p networkConfigName="" \
  --skip-secrets \
  -o /path/to/output
```

## OCI Source

All templates render KCL modules from:

```
oci://ghcr.io/stuttgart-things/claim-flux-kustomizations
```
