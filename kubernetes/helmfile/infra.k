import .helmfile_schema

helmDefaults = helmfile_schema.HelmDefaults {
    verify = False
    wait = True
    timeout = 600
    recreatePods = False
    force = True
}

helmfiles = [
    helmfile_schema.HelmfileEntry {
        path = "git::https://github.com/stuttgart-things/helm.git@infra/cilium.yaml.gotmpl"
        values = [
            {config = "kind"}
            {configureLB = True}
            {ipRangeStart = "172.18.250.0"}
            {ipRangeEnd = "172.18.250.50"}
            {clusterName = "platform-cluster"}
        ]
    }
    helmfile_schema.HelmfileEntry {
        path = "git::https://github.com/stuttgart-things/helm.git@infra/cert-manager.yaml.gotmpl"
        values = [
            {config = "selfsigned"}
        ]
    }
]
