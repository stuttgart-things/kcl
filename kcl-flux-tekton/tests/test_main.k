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

assert len(resources) == 3, "Es sollten 3 Ressourcen generiert werden (Namespace, HelmRepository, HelmRelease)"

ns = resources[0]
repo = resources[1]
release = resources[2]

assert ns.metadata.name == "tekton-pipelines", "Namespace Name falsch"
assert repo["kind"] == "HelmRepository", "HelmRepository Kind falsch"
assert release.metadata.name == "tekton-pipelines", "HelmRelease Name falsch"
assert release.spec.chart.spec.version == "0.76.1", "Chart Version falsch"

print("✅ Alle Tekton-Tests erfolgreich!")
