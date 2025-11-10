



```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "name": "eso-only",
      "clusterName": "vcluster-k3s-tink5",
      "csiEnabled": true,
      "vsoEnabled": false,
      "esoEnabled": false
    }
  }
}' --format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}' | kubectl apply -f -
```
