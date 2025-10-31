import .schema

_path = option("ciliumPath") or "git::https://github.com/stuttgart-things/helm.git@infra/cilium.yaml.gotmpl"
_config = option("ciliumConfig") or "kind"
_configureLB = option("ciliumConfigureLB") or True
_ipRangeStart = option("ciliumIpRangeStart") or "172.18.250.0"
_ipRangeEnd = option("ciliumIpRangeEnd") or "172.18.250.50"
_clusterName = option("ciliumClusterName") or "kind"

app = schema.HelmfileEntry {
    path = _path
    values = [
        {
            config = _config
        },
        {
            configureLB = _configureLB
        },
        {
            ipRangeStart = _ipRangeStart
        },
        {
            ipRangeEnd = _ipRangeEnd
        },
        {
            clusterName = _clusterName
        }
    ]
}