

```bash
kcl run main.k -D params='{
    "oxr": {
      "spec": {
        "clusterName": "default",
        "vaultAddr": "https://vault.demo-infra.sthings-vsphere.labul.sva.de",
        "vaultTokenSecret": "vault",
        "k8sAuths": [
          {"name": "frontend", "tokenPolicies": ["read-secrets"]},
          {"name": "backend", "tokenPolicies": ["read-secrets","write-logs"]}
        ]
      }
    }
  }' --format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}'
```
