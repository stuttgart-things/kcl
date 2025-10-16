# KCL/XPLANE-CILIUM


```bash
kcl run main.k -D params='{
    "oxr": {
      "spec": {
        "name": "my-cilium",
        "targetName space": "production",
        "version": "1.19.0",
        "config": "kind",
        "clusterName": "kind",
        "kubeProxyReplacement": true,
        "routingMode": "native",
        "ipv4NativeRoutingCIDR": "10.244.0.0/16",
        "k8sServiceHost": "kind-control-plane",
        "k8sServicePort": 6443,
        "l2announcements_enabled": true,
        "l2announcements_leaseDuration": "3s",
        "l2announcements_leaseRenewDeadline": "1s",
        "l2announcements_leaseRetryPeriod": "500ms",
        "devices": ["eth0", "net0"],
        "externalIPs_enabled": true,
        "autoDirectNodeRoutes": true,
        "operator_replicas": 3
    }
  }
}'
```

```bash
kcl mod push oci://ghcr.io/stuttgart-things/kcl-xplane-cilium
```