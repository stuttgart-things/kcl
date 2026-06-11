# XR-RANCHER-CLUSTER

KCL module for the `RancherCluster` XR (`resources.stuttgart-things.com/v1alpha1`),
the name/environment abstraction from the
[`rancher-cluster` Crossplane Configuration](../../../crossplane/crossplane-configurations/machinery/rancher-cluster).

A `RancherCluster` provisions a `provisioning.cattle.io` Cluster (generic
custom-node or Harvester-backed, k3s or rke2) on the Rancher management cluster,
wires the downstream kubeconfig into a `provider-kubernetes`
`ClusterProviderConfig`, bootstraps a namespace on the new cluster and
optionally registers it in Argo CD via clusterbook-operator.

Placement and per-environment defaults - `providerConfigRef`, `distro`,
`kubernetesVersion`, `rancherNamespace`, the Harvester infra identity
(image/network/credential) and the Argo CD target - are **not** set on the
claim; they come from the `EnvironmentConfig` selected by `environmentConfig`.
Precedence is **explicit XR value > EnvironmentConfig > KCL default**.

## Templates

| Template | Params | Purpose |
|---|---|---|
| `minimal`   | `name`, `environmentConfig` | Only the XRD-required `name`; everything else from the EnvironmentConfig. |
| `harvester` | + `cpuCount`, `memorySize`, `diskSize`, `quantity`, `argocdRegister` | Harvester preset (`infrastructure=harvester`); per-node sizing + Argo CD toggle. |
| `harvester-bootstrap` | + `reservationEnabled`, `reservationNetworkKey`, `vaultServer`, `vaultPkiPath`, `vaultTokenSecret`, `wildcardIssuerName` | Like `harvester`, but Argo CD registration is **ON by default** and the cluster ships bootstrap-ready: IP/DNS reservation + the full platform-profile label set (storage/security/network) + vault-pki annotations baked in. Mirrors the showcase `k3s-xp`. |
| `detailed`  | every spec field | Generic cluster with explicit distro, version, namespaces, bootstrap and full Argo CD registration. |

```bash
# minimal - distro/version/placement all from the EnvironmentConfig
kcl run oci://ghcr.io/stuttgart-things/xr-rancher-cluster --tag 0.2.0 \
  -D templateName=minimal -D name=k3s-min -D environmentConfig=default
```

```bash
# harvester - a 1-node Harvester k3s cluster, registered in Argo CD
kcl run oci://ghcr.io/stuttgart-things/xr-rancher-cluster --tag 0.2.0 \
  -D templateName=harvester -D name=k3s-xp \
  -D cpuCount=6 -D memorySize=6 -D quantity=1 -D argocdRegister=true
```

```bash
# harvester-bootstrap - a bootstrap-ready Harvester k3s cluster: registered in
# Argo CD with IP/DNS reservation + storage/security/network platform profiles
kcl run oci://ghcr.io/stuttgart-things/xr-rancher-cluster --tag 0.2.0 \
  -D templateName=harvester-bootstrap -D name=k3s-xp \
  -D cpuCount=6 -D memorySize=6 -D quantity=1 -D reservationNetworkKey=192.168.10
```

```bash
# detailed - a generic rke2 cluster with an Argo CD VIP endpoint
kcl run oci://ghcr.io/stuttgart-things/xr-rancher-cluster --tag 0.2.0 \
  -D templateName=detailed -D name=rke2-prod -D providerConfigRef=in-cluster \
  -D distro=rke2 -D kubernetesVersion=v1.31.5+rke2r1 -D rancherNamespace=fleet-default \
  -D bootstrapNamespace=platform-system -D argocdRegister=true -D argocdNamespace=argocd \
  -D argocdProviderConfigRef=rancher-mgmt -D argocdServer=https://192.168.10.135:6443
```

`cpuCount`/`memorySize`/`diskSize`/`quantity` are coerced to integers (XRD type),
and `argocdRegister` accepts `true`/`false`/`1`/`0`/`yes`. The map-typed fields
(`clusterLabels`, `machineGlobalConfig`, `argocd.labels/annotations`) are passed
via a params data file rather than `-D`; see `ranchercluster-data.yaml`.
