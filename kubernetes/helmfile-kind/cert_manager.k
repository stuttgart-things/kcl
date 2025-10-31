import .schema

_path = option("certManagerPath") or "git::https://github.com/stuttgart-things/helm.git@infra/cert-manager.yaml.gotmpl"
_config = option("certManagerConfig") or "selfsigned"

app = schema.HelmfileEntry {
    path = _path
    values = [
        {
            config = _config
        }
    ]
}
