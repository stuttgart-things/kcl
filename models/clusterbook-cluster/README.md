# Clusterbook-Cluster KCL Module

Type-safe KCL schemas for the
[clusterbook-operator](https://github.com/stuttgart-things/clusterbook-operator)
custom resources, generated from the upstream CRDs.

Includes:

- `ClusterbookCluster` (`clusterbook.stuttgart-things.com/v1alpha1`)

A `ClusterbookCluster` reserves an IP (and optionally a wildcard DNS record)
from clusterbook for a target Kubernetes cluster, then either creates or
enriches an Argo CD cluster `Secret` so the cluster shows up in Argo CD with
clusterbook-derived labels and annotations for `ApplicationSet` selection.

## Installation

```bash
# Add module to your KCL project
kcl mod add oci://ghcr.io/stuttgart-things/clusterbook-cluster

# Or add to kcl.mod manually
[dependencies]
clusterbook-cluster = { oci = "oci://ghcr.io/stuttgart-things/clusterbook-cluster", tag = "0.0.1" }
```

## Usage

### ClusterbookCluster (managed mode — kubeconfig Secret in)

```python
import clusterbook-cluster.v1alpha1.clusterbook_stuttgart_things_com_v1alpha1_clusterbook_cluster as cbk_mod

cluster = cbk_mod.ClusterbookCluster {
    metadata = {
        name = "philly"
    }
    spec = {
        networkKey = "10.31.101"
        clusterName = "philly"
        createDNS = True
        preserveKubeconfigServer = True
        kubeconfigSecretRef = {
            name = "philly"
            namespace = "argocd"
        }
        providerConfigRef = {
            name = "default"
        }
        argocdNamespace = "argocd"
        labels = {
            "env" = "lab"
            "role" = "mgmt"
            "auto-project" = "true"
        }
        releaseOnDelete = True
    }
}

items = [cluster]
```

### ClusterbookCluster (enrich mode — existing Argo CD cluster Secret)

```python
import clusterbook-cluster.v1alpha1.clusterbook_stuttgart_things_com_v1alpha1_clusterbook_cluster as cbk_mod

cluster = cbk_mod.ClusterbookCluster {
    metadata = {
        name = "denver"
    }
    spec = {
        networkKey = "10.31.103"
        clusterName = "denver"
        createDNS = True
        useFQDNAsServer = True
        serverSubdomain = "api"
        existingSecretRef = {
            name = "denver-cluster"
            namespace = "argocd"
        }
        providerConfigRef = {
            name = "default"
        }
    }
}

items = [cluster]
```

`kubeconfigSecretRef` and `existingSecretRef` are mutually exclusive — exactly
one must be set.

## Rendering

```bash
# Render the example
kcl run examples/clusterbook_cluster.k

# Render and pipe to kubectl for a dry-run
kcl run examples/clusterbook_cluster.k | kubectl apply --dry-run=client -f -

# Render with parameters from the CLI
kcl run examples/clusterbook_cluster.k \
  -D clusterName=denver \
  -D networkKey=10.31.103 \
  -D kubeconfigSecretName=denver-kubeconfig
```

## Testing

```bash
kcl test ./...
```

Expected output:

```
test_clusterbook_cluster_managed: PASS
test_clusterbook_cluster_enrich: PASS
PASS: 2/2
```

## CRD Source

- **Upstream**: [stuttgart-things/clusterbook-operator](https://github.com/stuttgart-things/clusterbook-operator)
- **CRD URL**:
  - https://raw.githubusercontent.com/stuttgart-things/clusterbook-operator/main/kcl/crds/clusterbook.stuttgart-things.com_clusterbookclusters.yaml
- **Conversion Tool**: `kcl import -m crd` (same tool wrapped by the
  `create-object-module-from-crd` Taskfile task)

## Re-generating Models

```bash
# Download the upstream CRD
mkdir -p /tmp/clusterbook-crds && cd /tmp/clusterbook-crds
curl -fsSL -O https://raw.githubusercontent.com/stuttgart-things/clusterbook-operator/main/kcl/crds/clusterbook.stuttgart-things.com_clusterbookclusters.yaml

# Convert to KCL schemas
cd models/clusterbook-cluster
kcl import -m crd /tmp/clusterbook-crds/clusterbook.stuttgart-things.com_clusterbookclusters.yaml

# The importer writes into ./models — flatten it back to the module root
mv models/v1alpha1 . && mv models/k8s . && rm -rf models
```
