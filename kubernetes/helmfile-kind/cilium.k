import .schema

_path = option("ciliumPath") or "git::https://github.com/stuttgart-things/helm.git@infra/cilium.yaml.gotmpl"
_config = option("ciliumConfig") or "kind"
_configureLB_option = option("cilium_configure_lb")
_configureLB: bool = True if _configureLB_option == None else (False if _configureLB_option == "false" or _configureLB_option == "False" else True)
_ipRangeStart = option("ciliumIpRangeStart") or "172.18.250.0"
_ipRangeEnd = option("ciliumIpRangeEnd") or "172.18.250.50"
_clusterName = option("ciliumClusterName") or "kind"

_app = schema.HelmfileEntry {
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
