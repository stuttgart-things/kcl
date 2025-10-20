# stuttgart-things/kcl

KCL modules for Crossplane compositions and configurations. This repository contains reusable KCL modules that generate Kubernetes resources for various infrastructure and application services.

## Available Modules

| Module | Version | OCI Registry | Description |
|--------|---------|--------------|-------------|
| [xplane-vault-config](#xplane-vault-config) | 0.1.0 | `oci://ghcr.io/stuttgart-things/xplane-vault-config` | Vault services (CSI, VSO, ESO) + RBAC |
| [xplane-vcluster](#xplane-vcluster) | Latest | `oci://ghcr.io/stuttgart-things/xplane-vcluster` | VCluster with connection management |
| [xplane-cilium](#xplane-cilium) | Latest | `oci://ghcr.io/stuttgart-things/xplane-cilium` | Cilium CNI with L2 announcements |
| [xplane-helm-release](#xplane-helm-release) | Latest | `oci://ghcr.io/stuttgart-things/xplane-helm-release` | Generic Helm chart deployment |
| [crossplane-provider-helm](#crossplane-provider-helm) | 0.1.1 | `oci://ghcr.io/stuttgart-things/crossplane-provider-helm` | Base Helm provider models |

<details><summary><b>XPLANE-VAULT-CONFIG</b></summary>

A comprehensive KCL module for deploying Vault-related services in Kubernetes using Crossplane Helm and Kubernetes providers.

### Services Included
| Service | Description | Configurable |
|---------|-------------|--------------|
| **Secrets Store CSI Driver** | Kubernetes CSI driver for mounting secrets from external systems | ✅ |
| **Vault Secrets Operator** | HashiCorp Vault integration for Kubernetes secret management | ✅ |
| **External Secrets Operator** | Kubernetes operator for syncing secrets from external systems | ✅ |
| **Kubernetes RBAC** | ServiceAccounts, Secrets, and ClusterRoleBindings for service authentication | ✅ |
| **Token Readers** | Automatic ServiceAccount JWT token extraction to connection secrets | ✅ |

### Features
- ✅ Automatic namespace creation
- ✅ Configurable chart versions
- ✅ Flexible service combinations (enable/disable individual components)
- ✅ Crossplane-compliant resource annotations
- ✅ ServiceAccount token extraction for external authentication
- ✅ Support for both kubeconfig path and content configurations

### Quick Install
```bash
kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-config
```

### Generated Resources
Up to 16 Kubernetes resources including namespaces, Helm releases, ServiceAccounts, Secrets, ClusterRoleBindings, and token readers.

</details>

<details><summary><b>XPLANE-VCLUSTER</b></summary>

KCL module for deploying VCluster instances with production-ready configuration and automatic connection secret management.

### Services Included
| Component | Description | Auto-Generated |
|-----------|-------------|----------------|
| **VCluster Deployment** | Virtual Kubernetes clusters via Crossplane Helm Provider | ✅ |
| **Connection Secret Management** | Automatic kubeconfig extraction and secret creation | ✅ |
| **ProviderConfig Generation** | Ready-to-use Kubernetes and Helm ProviderConfigs | ✅ |
| **Multi-Cluster Access** | Support for multiple kubeconfig secrets with custom contexts | ✅ |

### Architecture Flow
```
VCluster Pod → Creates Secret → Object observes Secret → Connection Secret → ProviderConfigs
```

### Features
- ✅ Production-ready VCluster configuration with persistence
- ✅ NodePort service configuration for external access
- ✅ Custom Subject Alternative Names (SANs) support
- ✅ Automatic connection secret extraction from VCluster
- ✅ Generated ProviderConfigs for immediate use
- ✅ Support for additional kubeconfig secrets
- ✅ OCI registry publishing support

### Quick Install
```bash
kcl mod add oci://ghcr.io/stuttgart-things/xplane-vcluster
```

</details>

<details><summary><b>XPLANE-CILIUM</b></summary>

KCL module for deploying Cilium CNI with advanced networking features through Crossplane.

### Networking Features
| Feature | Description | Configurable |
|---------|-------------|--------------|
| **Cilium CNI** | Advanced Kubernetes networking and security | ✅ |
| **L2 Announcements** | Load balancer IP advertisement with timing controls | ✅ |
| **Native Routing** | Direct pod-to-pod communication | ✅ |
| **Kube-Proxy Replacement** | Enhanced service handling | ✅ |

### Routing Modes
| Mode | Description | Use Case |
|------|-------------|----------|
| `native` | Direct routing without encapsulation | High performance, L3 connectivity |
| `vxlan` | VXLAN overlay networking | Cross-subnet communication |
| `geneve` | Generic Network Virtualization Encapsulation | Advanced overlay scenarios |

### Features
- ✅ Configurable routing modes (native, vxlan, geneve)
- ✅ L2 announcement configuration with timing controls
- ✅ External IP and direct node route support
- ✅ Multi-device networking configuration
- ✅ Operator replica scaling
- ✅ Custom k8s service endpoint configuration

### Quick Install
```bash
kcl mod add oci://ghcr.io/stuttgart-things/xplane-cilium
```

</details>

<details><summary><b>XPLANE-HELM-RELEASE</b></summary>

General-purpose KCL module for deploying any Helm chart through Crossplane Kubernetes provider.

### Deployment Methods
| Method | Provider | Resource Type | Use Case |
|--------|----------|---------------|----------|
| **Kubernetes Object** | `kubernetes.crossplane.io` | `Object` wrapping `HelmChart` | Any Helm chart via K8s provider |
| **Direct Helm** | `helm.crossplane.io` | `Release` | Direct Helm provider usage |

### Supported Chart Sources
| Source Type | Example | Supported |
|-------------|---------|-----------|
| **Public Repositories** | `https://charts.bitnami.com/bitnami` | ✅ |
| **Private Repositories** | `https://private.charts.com/repo` | ✅ |
| **OCI Registries** | `oci://registry.com/charts` | ✅ |
| **Git Repositories** | `git+https://github.com/user/charts` | ✅ |

### Features
- ✅ Support for any Helm chart and repository
- ✅ Configurable chart versions and values
- ✅ Namespace management
- ✅ Crossplane provider config reference
- ✅ Flexible value configuration via maps/objects

### Quick Install
```bash
kcl mod add oci://ghcr.io/stuttgart-things/xplane-helm-release
```

</details>

<details><summary><b>CROSSPLANE-PROVIDER-HELM</b></summary>

Base KCL models and examples for Crossplane Helm Provider integration.

### Available Models
| Resource | API Version | Description |
|----------|-------------|-------------|
| **Release** | `helm.crossplane.io/v1beta1` | Complete Helm Release resource definitions |
| **ProviderConfig** | `helm.crossplane.io/v1beta1` | Provider configuration patterns |

### Example Applications
| Application | Chart | Repository | Features |
|-------------|-------|------------|----------|
| **Nginx** | `nginx` | `bitnami` | LoadBalancer service, replica scaling |
| **PostgreSQL** | `postgresql` | `bitnami` | Persistent storage, authentication |

### Usage Patterns
| Pattern | Description | Code Example |
|---------|-------------|--------------|
| **Direct Import** | Import and use Helm models directly | `import crossplane_provider_helm.models...` |
| **Composition** | Build higher-level modules using base models | See other modules in this repo |
| **Extension** | Extend models with custom logic | Custom validation and defaults |

### Features
- ✅ Complete Helm Release resource definitions
- ✅ Example configurations for Nginx, PostgreSQL
- ✅ Provider configuration patterns
- ✅ Reusable component library

### Quick Install
```bash
kcl mod add oci://ghcr.io/stuttgart-things/crossplane-provider-helm
```

</details>

## How to Consume

<details><summary><b>OCI REGISTRY INSTALLATION</b></summary>

### Quick Installation
```bash
# Add all modules at once
kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-config
kcl mod add oci://ghcr.io/stuttgart-things/xplane-vcluster
kcl mod add oci://ghcr.io/stuttgart-things/xplane-cilium
kcl mod add oci://ghcr.io/stuttgart-things/xplane-helm-release
kcl mod add oci://ghcr.io/stuttgart-things/crossplane-provider-helm
```

### Individual Module Installation
| Module | Command |
|--------|---------|
| **Vault Config** | `kcl mod add oci://ghcr.io/stuttgart-things/xplane-vault-config` |
| **VCluster** | `kcl mod add oci://ghcr.io/stuttgart-things/xplane-vcluster` |
| **Cilium CNI** | `kcl mod add oci://ghcr.io/stuttgart-things/xplane-cilium` |
| **Helm Release** | `kcl mod add oci://ghcr.io/stuttgart-things/xplane-helm-release` |
| **Provider Models** | `kcl mod add oci://ghcr.io/stuttgart-things/crossplane-provider-helm` |

### Project Setup
```bash
# Create a kcl.mod file if you don't have one
kcl mod init <your-module-name>

# Verify installation
kcl mod graph
```

</details>

<details><summary><b>USAGE EXAMPLES</b></summary>

#### Vault Configuration
```kcl
import xplane_vault_config as vault

# Configure vault services
vault_config = vault.items({
    clusterName = "my-cluster"
    enableCSI = True
    enableVSO = True
    enableESO = False
    csiChartVersion = "v1.5.4"
    vsoChartVersion = "v1.0.1"
    esoChartVersion = "v0.20.3"
    kubeconfig_path = "/path/to/kubeconfig"
})
```

#### VCluster Deployment
```kcl
import xplane_vcluster as vcluster

# Deploy VCluster with connection secrets
vcluster_config = vcluster.items({
    name = "dev-cluster"
    version = "0.29.0"
    clusterName = "production"
    targetNamespace = "vcluster-dev"
    nodePort = 32443
    extraSANs = ["dev.example.com", "10.0.0.100"]
    serverUrl = "https://dev.example.com:32443"
})
```

#### Cilium CNI
```kcl
import xplane_cilium as cilium

# Configure Cilium with L2 announcements
cilium_config = cilium.items({
    name = "cilium-cni"
    targetNamespace = "kube-system"
    version = "1.19.0"
    config = "production"
    clusterName = "k8s-prod"
    routingMode = "native"
    l2announcements_enabled = True
    autoDirectNodeRoutes = True
})
```

#### Generic Helm Chart
```kcl
import xplane_helm_release as helm

# Deploy any Helm chart
helm_config = helm.items({
    name = "nginx-ingress"
    namespace = "ingress-nginx"
    chart = "ingress-nginx"
    repository = "https://kubernetes.github.io/ingress-nginx"
    version = "4.8.3"
    cluster = "production-cluster"
    values = {
        controller = {
            service = {
                type = "LoadBalancer"
            }
        }
    }
})
```

#### Direct Helm Provider Usage
```kcl
import crossplane_provider_helm.models.v1beta1.helm_crossplane_io_v1beta1_release as helm

# Direct Helm Release usage
nginx = helm.Release {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {name = "nginx-prod"}
    spec = {
        providerConfigRef = {name = "default"}
        forProvider = {
            chart = {
                name = "nginx"
                repository = "https://charts.bitnami.com/bitnami"
                version = "15.0.0"
            }
            namespace = "production"
            values = {
                replicaCount = 3
                service = {type = "LoadBalancer"}
            }
        }
    }
}
```

</details>

<details><summary><b>KEY PARAMETERS BY MODULE</b></summary>

#### xplane-vault-config
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clusterName` | string | **required** | Name of the target Kubernetes cluster |
| `enableCSI` | bool | `False` | Enable Secrets Store CSI Driver |
| `enableVSO` | bool | `False` | Enable Vault Secrets Operator |
| `enableESO` | bool | `False` | Enable External Secrets Operator |
| `csiChartVersion` | string | `"v1.5.4"` | Chart version for CSI Driver |
| `vsoChartVersion` | string | `"v1.0.1"` | Chart version for Vault Secrets Operator |
| `esoChartVersion` | string | `"v0.20.3"` | Chart version for External Secrets Operator |
| `kubeconfig_path` | string | `""` | Path to kubeconfig file |
| `kubeconfig_content` | string | `""` | Inline kubeconfig content |

#### xplane-vcluster
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | **required** | VCluster release name |
| `version` | string | `"0.29.0"` | VCluster chart version |
| `clusterName` | string | `"kind"` | Crossplane provider config reference |
| `targetNamespace` | string | `"vcluster"` | Target namespace for VCluster |
| `storageClass` | string | `"standard"` | Storage class for persistence |
| `nodePort` | int | `32443` | External NodePort for access |
| `extraSANs` | list | `["localhost"]` | Additional Subject Alternative Names |
| `serverUrl` | string | `"https://localhost:32443"` | External server URL |

#### xplane-cilium
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | **required** | Cilium release name |
| `version` | string | `"1.19.0"` | Cilium chart version |
| `clusterName` | string | **required** | Target cluster name |
| `routingMode` | string | `"native"` | Routing mode (native/vxlan/geneve) |
| `l2announcements_enabled` | bool | `True` | Enable L2 announcements |
| `kubeProxyReplacement` | bool | `True` | Replace kube-proxy |
| `autoDirectNodeRoutes` | bool | `True` | Enable direct node routes |
| `operator_replicas` | int | `3` | Number of operator replicas |

#### xplane-helm-release
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | **required** | Helm release name |
| `chart` | string | **required** | Helm chart name |
| `repository` | string | **required** | Chart repository URL |
| `version` | string | **required** | Chart version to deploy |
| `namespace` | string | `"default"` | Target namespace |
| `cluster` | string | **required** | Crossplane provider config |
| `values` | object | `{}` | Helm values configuration |

</details>

<details><summary><b>GENERATED RESOURCES</b></summary>

### Resource Overview by Module

| Module | Max Resources | Resource Types |
|--------|---------------|----------------|
| **xplane-vault-config** | 16 | Namespaces, Helm Releases, ServiceAccounts, Secrets, ClusterRoleBindings, Token Readers |
| **xplane-vcluster** | 4 | Helm Release, Object (Secret Observer), ProviderConfigs (K8s + Helm) |
| **xplane-cilium** | 1 | Helm Release |
| **xplane-helm-release** | 1 | Kubernetes Object wrapping HelmChart |
| **crossplane-provider-helm** | Variable | Raw Helm Release resources |

### Resource Details

#### xplane-vault-config Resources
| Resource Type | Count | Purpose |
|---------------|-------|---------|
| **Namespaces** | 1-3 | Automatic creation for each enabled service |
| **Helm Releases** | 1-3 | Crossplane Helm releases (CSI/VSO/ESO) |
| **ServiceAccounts** | 1-3 | Service authentication |
| **Secrets** | 1-3 | ServiceAccount token storage |
| **ClusterRoleBindings** | 1-3 | RBAC permissions |
| **Token Readers** | 1-3 | JWT token extraction objects |

#### Authentication Tokens
ServiceAccount JWT tokens are automatically extracted and made available in connection secrets with the key `token`. These can be used for external service authentication.

#### VCluster Connection Flow
```
VCluster → Secret Creation → Object Observer → Connection Secret → ProviderConfigs
```

</details>

## Development

### Prerequisites

- [KCL](https://kcl-lang.io/) installed
- [Task](https://taskfile.dev/) for automation
- Access to OCI registry for publishing

### Local Development

```bash
# Clone the repository
git clone https://github.com/stuttgart-things/kcl.git
cd kcl

# Run development tasks
task do

# Test a specific module
cd xplane-vault-config
kcl run main.k -D params='{"oxr": {"spec": {"clusterName": "test-cluster", "enableCSI": true}}}'
```

### Publishing Modules

Follow the automated workflow defined in `.container-use/decisions.md`:

1. **Development**: Create/modify KCL modules following team standards
2. **Testing**: Validate syntax and resource generation
3. **Versioning**: Use semantic versioning with conventional commits
4. **Publication**: Automated Git commit and OCI registry push

```bash
# Example workflow
git add .
git commit -m "feat: add new feature to xplane-vault-config module"
kcl mod push oci://ghcr.io/stuttgart-things/<module-name>
git push origin <branch-name>
```

## Team Standards

Refer to `.container-use/decisions.md` for comprehensive development guidelines including:

- Variable naming patterns (Crossplane-compliant)
- Boolean handling best practices
- Mandatory resource annotations
- Automated Git and OCI workflows

## Support

For issues, feature requests, or contributions, please visit the [stuttgart-things/kcl](https://github.com/stuttgart-things/kcl) repository.
