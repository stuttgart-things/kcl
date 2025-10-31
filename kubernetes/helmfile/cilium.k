import .schema

cilium = schema.HelmfileEntry {
    path = "git::https://github.com/stuttgart-things/helm.git@infra/cilium.yaml.gotmpl"
    values = [
        {
            config = "kind"
        },
        {
            configureLB = True
        }
    ]
}