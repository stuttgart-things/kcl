# claim-flux-kustomizations

Rendert Flux-`Kustomization`- und `GitRepository`-Objekte fuer die
Cluster-Repositories. Die erzeugten Objekte tragen die Annotation
`managed-by: kcl-flux-kustomizations` — daran erkennt man im Cluster-Repo,
was aus diesem Modul stammt und was von Hand geschrieben wurde.

## Benutzung

Welches Objekt entsteht, entscheidet `templateName`:

```bash
kcl run . -D templateName=openebs -D sourceRefName=flux-infra
kcl run . -D templateName=gitrepository -D name=flux-infra \
          -D url=https://github.com/stuttgart-things/flux.git -D tag=v1.24.1
```

Als OCI-Modul, so rufen es die dagger-Module auf:

```bash
dagger call -m github.com/stuttgart-things/dagger/kcl run \
  --oci-source ghcr.io/stuttgart-things/claim-flux-kustomizations \
  --parameters "templateName=openebs,name=openebs,sourceRefName=flux-infra" \
  --entrypoint main.k
```

## Templates

| | |
|---|---|
| Basis | `gitops`, `infrastructure`, `gitrepository` |
| Storage | `openebs`, `nfs-csi` |
| Netzwerk | `cilium-gateway` |
| Zertifikate | `cert-manager`, `cert-manager-selfsigned`, `trust-manager` |
| Crossplane | `crossplane-install`, `crossplane-functions`, `crossplane-configs` |
| Vault | `vault`, `vault-autounseal`, `vault-httproute` |
| Apps | `minio`, `minio-httproute`, `clusterbook`, `flux-web`, `headlamp`, `uptime-kuma`, `prometheus` |

Zu jedem Template liegt unter `templates/` eine `ClaimTemplate`-Datei, die
die Parameter mit Titeln, Defaults und Enums beschreibt — das ist die
Quelle fuer die Formulare, nicht dieses README.

## Parameter

Gemeinsam fuer alle Templates: `name`, `namespace`, `interval`,
`retryInterval`, `timeout`, `prune`, `wait`, `force`, `suspend`,
`sourceRefKind`, `sourceRefName`, `sourceRefNamespace`, `path`,
`targetNamespace`, `dependsOnNames`.

Template-spezifische Parameter landen in `spec.postBuild.substitute`.
Dabei gilt: **der Schluessel muss zu dem passen, was die Manifeste im
`flux`-Repo auslesen.** Weicht er ab, faellt die Substitution still aus
und der Chart nimmt seinen eigenen Default — sichtbar wird das erst,
wenn jemand eine Version bewusst pinnt und trotzdem eine andere bekommt.

## Tests

CI (`lint-and-test`) laeuft nur fuer geaenderte Module und prueft
`kcl fmt .`, `kcl lint .`, `kcl run .` sowie die Modulstruktur —
`kcl.mod`, `main.k` und dieses README muessen vorhanden sein.
