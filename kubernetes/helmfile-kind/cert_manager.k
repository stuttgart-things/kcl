import .schema

app = schema.HelmfileEntry {
    path = "git::https://github.com/stuttgart-things/helm.git@infra/cert-manager.yaml.gotmpl"
    values = [
        {
            config = "selfsigned"
        }
    ]
}