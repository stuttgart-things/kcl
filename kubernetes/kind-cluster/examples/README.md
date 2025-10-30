# KCL Kind Cluster Examples

This directory contains example configuration files demonstrating various cluster setups.

## Quick Comparison

| Example | Best For | Key Features |
|---------|----------|--------------|
| [custom-ports.k](custom-ports.k) | Non-standard port requirements | Custom port list (6443, 8080, 8443, 9090, 3000) |
| [minimal-cluster.k](minimal-cluster.k) | Testing, CI/CD | Only API port, no custom registry |
| [dev-cluster.k](dev-cluster.k) | Local development | Latest K8s, standard ports, kube-proxy enabled |

## Available Examples

### 1. Custom Port Mappings ([custom-ports.k](custom-ports.k))

Demonstrates how to completely override the port mappings with a custom list.

**Features:**
- Custom API server port (6443)
- HTTP/HTTPS ports (8080, 8443)
- Custom application ports (9090, 3000)

**Usage:**
```bash
kcl run main.k examples/custom-ports.k
```

### 2. Minimal Cluster ([minimal-cluster.k](minimal-cluster.k))

Creates a minimal cluster with just the essentials.

**Features:**
- Only API server port mapped (6443)
- Uses standard Docker Hub (no custom mirror)
- Minimal configuration for testing

**Usage:**
```bash
kcl run main.k examples/minimal-cluster.k
```

### 3. Development Cluster ([dev-cluster.k](dev-cluster.k))

A cluster optimized for local development.

**Features:**
- Uses latest Kubernetes version (v1.35.0)
- Standard API server port (6443)
- Fewer port mappings (30000-30002)
- Local temporary storage paths
- Kube-proxy enabled for easier debugging

**Usage:**
```bash
kcl run main.k examples/dev-cluster.k
```

## Creating Your Own Examples

To create your own configuration:

1. Create a new `.k` file in this directory
2. Override any variables you want to customize (prefix with `_`)
3. Run with: `kcl run main.k examples/your-config.k`

### Available Variables to Override

See the main [README.md](../README.md) for the complete list of configuration options.

**Common overrides:**
```kcl
# Cluster basics
_clusterName = "my-cluster"
_nodeImage = "kindest/node:v1.35.0"

# Networking
_apiServerPort = 6443
_kubeProxyMode = "iptables"

# Ports
_extraPortMappings = [...]  # Custom port list

# Storage
_mountBasePath = "/data/storage"

# Registry
_registryMirror1 = "https://my-registry.example.com"
```

## Combining Examples

You can combine multiple configuration files:

```bash
# Use dev cluster settings + custom ports
kcl run main.k examples/dev-cluster.k examples/custom-ports.k
```

**Note:** Files are processed left to right, so later files override earlier ones.
