# KCL Kind Cluster Configuration

This KCL configuration generates a Kind (Kubernetes in Docker) cluster configuration with flexible, dynamic settings.

## Features

- **Dynamic configuration** with minimal hardcoded values
- **Configurable port mappings** with range-based generation
- **Flexible mount paths** for worker nodes
- **Customizable networking** settings
- **Feature gates** control

## Configuration Variables

Variables are defined with underscore prefix (private) to prevent them from appearing in the output, but **options are passed without underscores** for cleaner CLI usage.

### Quick Reference

| What You Want | How to Do It |
|---------------|--------------|
| Different Kubernetes version | `-D nodeImage="kindest/node:v1.35.0"` |
| Change API server port | `-D apiServerPort=6443` |
| More ports (e.g., 10 ports) | `-D portRangeCount=10` |
| Different port range | `-D portRangeStart=30000 -D portRangeCount=5` |
| Custom port list | `-D 'extraPortMappings=[{...}]'` or use file |
| Change cluster name | `-D clusterName="my-cluster"` |
| Different mount path | `-D mountBasePath="/data"` |
| Custom registry mirrors | `-D 'registryMirrors=["https://my-registry.com"]'` |
| Enable kube-proxy | `-D kubeProxyMode="iptables"` |
| Use preset config | `kcl run main.k examples/dev-cluster.k` |

### Basic Configuration

| Option Name | Default | Description |
|----------|---------|-------------|
| `nodeImage` | `"kindest/node:v1.34.0"` | Kubernetes node image for all nodes |
| `clusterName` | `"platform-cluster"` | Cluster name (also used in mount paths) |

### Networking Configuration

| Option Name | Default | Description |
|----------|---------|-------------|
| `apiServerAddress` | `"0.0.0.0"` | API server bind address |
| `disableDefaultCNI` | `True` | Disable default CNI (for custom CNI installation) |
| `kubeProxyMode` | `"none"` | Kube-proxy mode (`"none"`, `"iptables"`, `"ipvs"`) |

### Feature Gates

| Option Name | Default | Description |
|----------|---------|-------------|
| `imageVolumeFeature` | `True` | Enable ImageVolume feature gate |

### Port Mappings (Control Plane Node)

| Option Name | Default | Description |
|----------|---------|-------------|
| `apiServerPort` | `31643` | Host port for Kubernetes API server (maps to container port 6443) |
| `portRangeStart` | `32443` | Starting port for additional port range |
| `portRangeCount` | `6` | Number of ports to map in the range |

**Generated ports**: API server port + range of ports (e.g., 32443-32448)

### Storage Mounts (Worker Nodes)

| Option Name | Default | Description |
|----------|---------|-------------|
| `mountBasePath` | `"/mnt"` | Base path on the host for mounts |
| `containerMountPath` | `"/data"` | Path inside the container |

**Generated mount paths**:
- Worker 1: `${mountBasePath}/${clusterName}1` → `${containerMountPath}`
- Worker 2: `${mountBasePath}/${clusterName}2` → `${containerMountPath}`

### Container Registry Mirrors

| Option Name | Default | Description |
|----------|---------|-------------|
| `registryMirrors` | `["https://docker.harbor.idp.kubermatic.sva.dev", "https://registry-1.docker.io"]` | List of registry mirror endpoints (can contain 0, 1, 2, or more mirrors) |

## Usage Examples

### Quick Start

```bash
# Use defaults
kcl run main.k

# Use a pre-configured example
kcl run main.k examples/dev-cluster.k

# Customize with CLI options
kcl run main.k -D nodeImage="kindest/node:v1.35.0" -D apiServerPort=6443

# Combine example + overrides
kcl run main.k examples/dev-cluster.k -D clusterName="my-cluster"
```

See [examples/](examples/) directory for more pre-configured setups.

### Basic Usage (All Defaults)

```bash
kcl run main.k
```

This generates a cluster with:
- 1 control-plane node with ports: 31643 (API), 32443-32448
- 2 worker nodes with mounts: `/mnt/platform-cluster1`, `/mnt/platform-cluster2`

### Custom Node Image

```bash
kcl run main.k -D nodeImage="kindest/node:v1.35.0"
```

### Custom Port Configuration

```bash
# Change API server port
kcl run main.k -D apiServerPort=6443

# Change port range
kcl run main.k -D portRangeStart=30000 -D portRangeCount=10

# This will map ports: 6443 (API) + 30000-30009
```

### Custom Storage Mounts

```bash
# Change base mount path
kcl run main.k -D mountBasePath="/data/storage"
# Results in: /data/storage/platform-cluster1, /data/storage/platform-cluster2

# Change cluster name (affects mounts)
kcl run main.k -D clusterName="dev-cluster"
# Results in: /mnt/dev-cluster1, /mnt/dev-cluster2

# Change container mount path
kcl run main.k -D containerMountPath="/var/data"
```

### Custom Registry Mirrors

```bash
# Use a single custom registry mirror
kcl run main.k -D 'registryMirrors=["https://my-registry.example.com"]'

# Use multiple registry mirrors (with fallbacks)
kcl run main.k -D 'registryMirrors=["https://mirror1.example.com", "https://mirror2.example.com", "https://mirror3.example.com"]'

# Use only Docker Hub (direct, no mirrors)
kcl run main.k -D 'registryMirrors=["https://registry-1.docker.io"]'

# Disable registry mirrors completely
kcl run main.k -D 'registryMirrors=[]'
```

### Custom Networking

```bash
# Enable default CNI
kcl run main.k -D disableDefaultCNI=False

# Change kube-proxy mode
kcl run main.k -D kubeProxyMode="iptables"

# Change API server address
kcl run main.k -D apiServerAddress="127.0.0.1"
```

### Combined Configuration

```bash
kcl run main.k \
  -D nodeImage="kindest/node:v1.35.0" \
  -D clusterName="dev-cluster" \
  -D apiServerPort=6443 \
  -D portRangeStart=30000 \
  -D portRangeCount=5 \
  -D mountBasePath="/storage" \
  -D kubeProxyMode="iptables"
```

Another example with dynamic API server address:

```bash
kcl run main.k \
  -D portRangeStart=32100 \
  -D portRangeCount=2 \
  -D clusterName=gitea \
  -D apiServerAddress=$(hostname -f) \
  -D 'registryMirrors=["https://docker.harbor.idp.kubermatic.sva.dev"]' \
  -D apiServerPort=${KUBE_API_PORT} > /tmp/cluster.yaml
```

**Important:** When passing `registryMirrors` via `-D`, you must use JSON array syntax with square brackets and quotes: `'registryMirrors=["url1", "url2"]'`. Don't pass it as a plain string.

### Output to File

```bash
# Generate YAML configuration
kcl run main.k > cluster.yaml

# Use with Kind
kind create cluster --config cluster.yaml
```

## Example Rendered Output

Default configuration renders as a proper Kind cluster YAML:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: platform-cluster
featureGates:
  ImageVolume: true
networking:
  apiServerAddress: '0.0.0.0'
  disableDefaultCNI: true
  kubeProxyMode: none
nodes:
- role: control-plane
  image: kindest/node:v1.34.0
  extraPortMappings:
  - containerPort: 6443
    hostPort: 31643
    protocol: TCP
  - containerPort: 32443
    hostPort: 32443
  - containerPort: 32444
    hostPort: 32444
  - containerPort: 32445
    hostPort: 32445
  - containerPort: 32446
    hostPort: 32446
  - containerPort: 32447
    hostPort: 32447
  - containerPort: 32448
    hostPort: 32448
- role: worker
  image: kindest/node:v1.34.0
  extraMounts:
  - hostPath: /mnt/platform-cluster1
    containerPath: /data
- role: worker
  image: kindest/node:v1.34.0
  extraMounts:
  - hostPath: /mnt/platform-cluster2
    containerPath: /data
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["https://docker.harbor.idp.kubermatic.sva.dev", "https://registry-1.docker.io"]
```

This output can be used directly with Kind:

```bash
kcl run main.k > cluster.yaml
kind create cluster --config cluster.yaml
```

## Cluster Topology

```
┌─────────────────────────────────┐
│     Control Plane Node          │
│  kindest/node:v1.34.0           │
│                                 │
│  Port Mappings:                 │
│  - 6443 → 31643 (API Server)    │
│  - 32443 → 32443                │
│  - 32444 → 32444                │
│  - 32445 → 32445                │
│  - 32446 → 32446                │
│  - 32447 → 32447                │
│  - 32448 → 32448                │
└─────────────────────────────────┘
           │
           ├─────────────────────────────────┐
           │                                 │
┌──────────▼──────────┐          ┌──────────▼──────────┐
│   Worker Node 1     │          │   Worker Node 2     │
│ kindest/node:v1.34.0│          │ kindest/node:v1.34.0│
│                     │          │                     │
│ Mount:              │          │ Mount:              │
│ Host: /mnt/         │          │ Host: /mnt/         │
│   platform-cluster1 │          │   platform-cluster2 │
│ Container: /data    │          │ Container: /data    │
└─────────────────────┘          └─────────────────────┘
```

## Files

- [main.k](main.k) - Main cluster configuration with dynamic variables
- [schema.k](schema.k) - Schema definitions for cluster components
- [README.md](README.md) - This file
- [examples/](examples/) - Example configurations for various use cases
  - [custom-ports.k](examples/custom-ports.k) - Custom port mappings
  - [minimal-cluster.k](examples/minimal-cluster.k) - Minimal cluster setup
  - [dev-cluster.k](examples/dev-cluster.k) - Development cluster configuration
  - [README.md](examples/README.md) - Examples documentation

## Advanced Usage

### Completely Custom Port Mappings

#### Method 1: Using `-D` flag with JSON

You can pass custom port mappings directly via the command line using JSON syntax:

```bash
kcl run main.k -D 'extraPortMappings=[{"containerPort": 6443, "hostPort": 6443, "protocol": "TCP"}, {"containerPort": 80, "hostPort": 8080}]'
```

**Notes:**
- Use **JSON syntax** (double quotes, colons) when passing via `-D`
- Enclose the entire JSON in single quotes to avoid shell interpretation
- For simple changes, use the simpler parameters (`apiServerPort`, `portRangeCount`) instead

**More examples:**

```bash
# Single port mapping
kcl run main.k -D 'extraPortMappings=[{"containerPort": 6443, "hostPort": 6443, "protocol": "TCP"}]'

# Multiple ports without protocol (defaults to TCP)
kcl run main.k -D 'extraPortMappings=[{"containerPort": 6443, "hostPort": 6443}, {"containerPort": 8080, "hostPort": 8080}]'

# Complex multi-port setup (easier to read when split)
kcl run main.k -D 'extraPortMappings=[
  {"containerPort": 6443, "hostPort": 6443, "protocol": "TCP"},
  {"containerPort": 80, "hostPort": 8080},
  {"containerPort": 443, "hostPort": 8443},
  {"containerPort": 9090, "hostPort": 9090}
]'
```

#### Method 2: Using a configuration file

For complex or reusable configurations, create a separate file:

**examples/custom-ports.k:**
```kcl
# Override the entire port mappings list
_extraPortMappings = [
    {containerPort = 6443, hostPort = 6443, protocol = "TCP"},
    {containerPort = 80, hostPort = 8080},
    {containerPort = 443, hostPort = 8443},
    {containerPort = 9090, hostPort = 9090},
]
```

Then run:
```bash
kcl run main.k examples/custom-ports.k
```

**How it works:**
- Variables in later files override variables in earlier files
- The `_extraPortMappings` variable from custom-ports.k replaces the computed one from main.k
- Use files for complex/reusable configs, use `-D` for quick one-off changes

### Simple Port Range Customization

For most use cases, just adjust the range parameters instead of overriding the entire list:

```bash
# Just need more ports? Increase the count
kcl run main.k -D portRangeCount=10

# Need different port range? Change the start
kcl run main.k -D portRangeStart=30000 -D portRangeCount=5

# Ports: 6443→31643 (API) + 30000-30004
```

### Using Environment Variables

You can also use environment variables with KCL:

```bash
# Set environment variables
export NODE_IMAGE="kindest/node:v1.35.0"
export CLUSTER_NAME="production"

# Use in KCL command
kcl run main.k -D nodeImage="${NODE_IMAGE}" -D clusterName="${CLUSTER_NAME}"
```

## Notes

- The cluster uses a custom containerd registry mirror for docker.io
- Default CNI is disabled to allow installation of custom CNI (e.g., Cilium, Calico)
- Kube-proxy mode is set to "none" for CNI-based proxy implementations
- ImageVolume feature gate is enabled by default
