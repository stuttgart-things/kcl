
import ..main as tekton

# Test: Standard TektonConfig
cfg = tekton.TektonConfig {
    name = "tekton-pipelines"
    namespace = "tekton-pipelines"
    version = "0.76.1"
    tenant = "sthings-team"
    chartRepo = "oci://ghcr.io/stuttgart-things/tekton"
}
resources = tekton.tektonResources(cfg)

assert len(resources) == 3, "Should generate 3 resources (Namespace, HelmRepository, HelmRelease)"

ns = resources[0]
repo = resources[1]
release = resources[2]

assert ns.metadata.name == "tekton-pipelines", "Namespace name incorrect"
assert repo["kind"] == "HelmRepository", "HelmRepository kind incorrect"
assert release.metadata.name == "tekton-pipelines", "HelmRelease name incorrect"
assert release.spec.chart.spec.version == "0.76.1", "Chart version incorrect"

print("✅ All Tekton tests passed!")
