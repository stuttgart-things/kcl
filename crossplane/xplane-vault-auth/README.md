# xplane-vault-auth

```bash
kcl run vault-k8s-auth.k -D params='{
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
  }' --format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}' | kubectl apply -f -
```

```bash
---
apiVersion: v1
kind: Secret
metadata:
  name: vault
  namespace: crossplane-system
type: Opaque
stringData:
  # HCL format - the value must be quoted in the HCL syntax
  terraform.tfvars: |
    vault_token = "hvs..."
```




```bash
kcl run --quiet examples/simple-auth.k | grep -A 1000 "^items:" | sed 's/^- /---\n/' | sed '1d' | sed 's/^  //'
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite: `kcl run tests/test_main.k`
6. Submit a pull request

## 📝 License

This project is licensed under the Apache License 2.0. See [LICENSE](../LICENSE) for details.

## 🔗 Related Projects

- [crossplane-provider-terraform](../crossplane-provider-terraform/) - Base Terraform provider module
- [xplane-vault-config](../xplane-vault-config/) - Complete Vault services configuration
- [Crossplane Terraform Provider](https://github.com/crossplane-contrib/provider-terraform) - Upstream provider
- [Stuttgart-Things Infrastructure](https://github.com/stuttgart-things) - Platform engineering resources

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/stuttgart-things/kcl/issues)
- **Documentation**: [Stuttgart-Things Docs](https://stuttgart-things.github.io)
- **Community**: [Stuttgart-Things Discussions](https://github.com/orgs/stuttgart-things/discussions)
