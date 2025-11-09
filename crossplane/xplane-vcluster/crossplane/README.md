# XPLANE-VCLUSTER

## GET KUBECONFIG FROM VCLUSTER

```bash
kubectl get secret vcluster-k3s-tink5-connection -n crossplane-system -o jsonpath='{.data.kubeconfig}' | base64 -d > vcluster-k3s-tink5.kubeconfig

export KUBECONFIG=vcluster-k3s-tink5.kubeconfig
kubectl get nodes
```

## CREATE TEST-OBJECT

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: test-namespace
spec:
  providerConfigRef:
    name: vcluster-k3s-tink5
  forProvider:
    manifest:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: test-namespace2
EOF
```
