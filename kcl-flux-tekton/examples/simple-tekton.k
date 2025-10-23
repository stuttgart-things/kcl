import ..main as tekton

cfg = tekton.TektonConfig {
    name = "tekton-pipelines"
    namespace = "tekton-pipelines"
    version = "0.76.1"
    tenant = "sthings-team"
    chartRepo = "oci://ghcr.io/stuttgart-things/tekton"
}

resources = tekton.tektonResources(cfg)
