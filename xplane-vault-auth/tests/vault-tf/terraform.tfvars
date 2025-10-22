k8s_auths = [
  {
    name           = "dev"
    namespace      = "default"
    token_policies = ["read-all-s3-kvv2", "read-write-all-s3-kvv2"]
    token_ttl      = 3600
  },
  {
    name           = "cicd"
    namespace      = "tektoncd"
    token_policies = ["read-all-tektoncd-kvv2"]
    token_ttl      = 3600
  }
]

cluster_name = "vcluster-tink1"
vault_addr = "https://vault.demo-infra.sthings-vsphere.labul.sva.de"
skip_tls_verify = true