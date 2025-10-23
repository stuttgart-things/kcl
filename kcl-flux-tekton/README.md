# kcl-flux-tekton

KCL-Modul zur Bereitstellung von Tekton über Flux (Helm/Kustomize) und Kubernetes-Ressourcen.

## Features
- Generiert Namespace, HelmRepository und HelmRelease für Tekton
- Nutzt flux-helmrelease und flux-kustomization als Abstraktion
- OCI-kompatibel, CI/CD-ready

## Installation
```kcl
kcl mod add oci://ghcr.io/stuttgart-things/kcl-flux-tekton
```

## Beispiel
```kcl
import kcl-flux-tekton.main as tekton
cfg = tekton.TektonConfig {
    name = "tekton-pipelines"
    namespace = "tekton-pipelines"
    version = "0.76.1"
    tenant = "sthings-team"
    chartRepo = "oci://ghcr.io/stuttgart-things/tekton"
}
resources = tekton.tektonResources(cfg)
```

## Ressourcen
- Namespace
- HelmRepository
- HelmRelease

## CRD-Quellen
- [release.yaml](../apps/flux/cicd/tekton/release.yaml)
- [requirements.yaml](../apps/flux/cicd/tekton/requirements.yaml)
- [kustomization.yaml](../apps/flux/cicd/tekton/kustomization.yaml)

## Entwicklung
- Tests und Beispiele im Ordner `examples/`
- Module basiert auf flux-helmrelease und flux-kustomization
