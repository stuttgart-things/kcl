


```bash
kcl run main.k -D params='{
  "oxr": {
    "spec": {
      "clusterName": "demo-infra",
      "deployTerraformProvider": true,
      "secrets": {
        "s3": {
          "namespace": "crossplane-system",
          "kvs": {
            "AWS_ACCESS_KEY_ID": "your-access-key",
            "AWS_SECRET_ACCESS_KEY": "your-secret-key",
            "AWS_REGION": "eu-central-1"
          }
        }
      }
    }
  }
}' --format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}' | kubectl apply -f -
```