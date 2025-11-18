# ArgoCD Deployment KCL Module

This KCL module provides a declarative way to deploy ArgoCD using Crossplane Helm and Kubernetes providers.

## Features

- **Core ArgoCD Deployment** via Helm Release
- **Optional Ingress Configuration** with TLS support
- **Optional Certificate Management** using cert-manager
- **Optional ArgoCD Vault Plugin (AVP)** with multiple plugin variants:
  - argocd-vault-plugin (basic)
  - argocd-vault-plugin-helm
  - argocd-vault-plugin-kustomize
  - helmfile support

## Configuration Parameters

All parameters support the `option("params")?.oxr?.spec?.` pattern with sensible defaults:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `name` | `argocd-deployment` | Configuration name |
| `targetNamespace` | `argocd` | Target namespace for ArgoCD |
| `version` | `8.2.5` | ArgoCD Helm chart version |
| `clusterName` | `kind` | Target cluster name (used for providerConfigRef) |
| `serviceType` | `ClusterIP` | Kubernetes service type (ClusterIP/NodePort/LoadBalancer) |
| `nodePortHttp` | - | Optional NodePort for HTTP service |
| `enableIngress` | `false` | Enable ingress resource |
| `hostname` | `argocd` | Hostname for ingress |
| `domain` | `example.com` | Domain for ingress |
| `ingressClassName` | `nginx` | Ingress class name |
| `createCertificateResource` | `false` | Create cert-manager Certificate resource |
| `issuerName` | `selfsigned` | Certificate issuer name |
| `issuerKind` | `ClusterIssuer` | Certificate issuer kind (ClusterIssuer/Issuer) |
| `certificateSecretName` | `argocd-server-tls` | TLS secret name for certificate |
| `adminPassword` | - | ArgoCD admin password |
| `adminPasswordMTime` | - | Admin password modification time |
| `enableAvp` | `false` | Enable ArgoCD Vault Plugin |
| `vaultAddr` | - | Vault server address |
| `vaultNamespace` | - | Vault namespace |
| `vaultRoleID` | - | Vault AppRole role ID |
| `vaultSecretID` | - | Vault AppRole secret ID |
| `imageAvp` | `quay.io/argoproj/argocd-vault-plugin:latest` | AVP image |
| `imageHelmfile` | `ghcr.io/helmfile/helmfile:latest` | Helmfile image |

## Usage Examples

### Basic Deployment

Deploy ArgoCD with default settings:

```bash
kcl run main.k
```

### Enable Ingress

Deploy with ingress enabled:

```bash
kcl run main.k -D params='{"oxr":{"spec":{"enableIngress":true}}}'
```

### Custom Hostname and Domain

Deploy with custom hostname and domain:

```bash
kcl run main.k -D params='{"oxr":{"spec":{"enableIngress":true,"hostname":"argocd","domain":"mydomain.com","ingressClassName":"nginx"}}}'
```

### Enable Certificate Management

Deploy with ingress and cert-manager certificate:

```bash
kcl run main.k -D params='{"oxr":{"spec":{"enableIngress":true,"createCertificateResource":true,"hostname":"argocd","domain":"mydomain.com","issuerName":"letsencrypt-prod","issuerKind":"ClusterIssuer"}}}'
```

### Enable ArgoCD Vault Plugin (AVP)

Deploy with Vault integration:

```bash
kcl run main.k -D params='{"oxr":{"spec":{"enableAvp":true,"vaultAddr":"https://vault.example.com","vaultNamespace":"admin","vaultRoleID":"your-role-id","vaultSecretID":"your-secret-id"}}}'
```

### Full Configuration

Deploy with all features enabled:

```bash
kcl run main.k -D params='{"oxr":{"spec":{"enableIngress":true,"enableAvp":true,"createCertificateResource":true,"hostname":"argocd","domain":"example.com","vaultAddr":"https://vault.example.com","vaultNamespace":"admin","vaultRoleID":"your-role-id","vaultSecretID":"your-secret-id","version":"8.2.5","adminPassword":"your-password","adminPasswordMTime":"2024-01-01T00:00:00Z"}}}'
```

### Save Output to File

Generate YAML output and save to file:

```bash
kcl run main.k -D params='{"oxr":{"spec":{"enableIngress":true}}}' > argocd-deployment.yaml
```

### NodePort Service

Deploy with NodePort service type:

```bash
kcl run main.k -D params='{"oxr":{"spec":{"serviceType":"NodePort","nodePortHttp":30080}}}'
```

## Generated Resources

The module conditionally generates the following Crossplane resources:

1. **Namespace** - Always created
2. **ArgoCD Helm Release** - Always created
3. **AVP Secret** - Created when `enableAvp=true`
4. **Certificate** - Created when `createCertificateResource=true`

All resources are wrapped in Crossplane `Object` or `Release` resources for GitOps-friendly deployment.

## Dependencies

This module requires the following KCL dependencies (defined in `kcl.mod`):

- `crossplane-provider-helm` (OCI: ghcr.io/stuttgart-things/crossplane-provider-helm:0.1.1)
- `crossplane-provider-kubernetes` (v0.18.0)

## Prerequisites

- Crossplane installed in the target cluster
- Crossplane Helm Provider configured
- Crossplane Kubernetes Provider configured
- ProviderConfig matching the `clusterName` parameter
- (Optional) cert-manager for certificate management
- (Optional) Vault server for AVP functionality
