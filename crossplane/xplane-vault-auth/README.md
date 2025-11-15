# XPLANE-VAULT-AUTH

## CREATE VAULT SECRET

```bash
# Create a tfvars file
cat > terraform.tfvars <<EOF
vault_token = "your-vault-token-here"
EOF

# Create the secret from file
kubectl create secret generic vault \
  -n crossplane-system \
  --from-file=terraform.tfvars=terraform.tfvars

# Clean up the file
rm terraform.tfvars
```

## RUN KCL RUN

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

```bash
kcl run --quiet oci://ghcr.io/stuttgart-things/xplane-vault-auth:0.1.2 \
  -D params='{
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
  }' --format yaml \
  | yq eval -P '.items[]' - \
  | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}'
```
