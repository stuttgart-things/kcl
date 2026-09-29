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
| Katalog-Bundles | `bundle` |

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

## Template `bundle`

Rendert die Kustomization, mit der ein Cluster ein Bundle aus dem
`flux`-Katalog nutzt (`./apps/platform/root`, `./infra/platform/root`, …).
Dazu kommen die ausgewählten `components`, `postBuild.substitute` und
`postBuild.substituteFrom`. So nutzt es blueprints' `render-cluster-apps`
([blueprints#206](https://github.com/stuttgart-things/blueprints/issues/206)).

```bash
dagger call -m github.com/stuttgart-things/dagger/kcl run \
  --oci-source ghcr.io/stuttgart-things/claim-flux-kustomizations?tag=0.4.0 \
  --parameters-file examples/bundle-params.yaml --entrypoint main.k
```

- `components`, `substitute`, `substituteFrom` und `dependsOnNames` nehmen
  Listen und Maps aus einer Parameterdatei. Der Weg über die Parameterdatei
  (`-Y`) erhält Werte mit `,` oder `=`; die Komma-Schreibweise über `-D`
  kann das nicht. Die Komma-Schreibweise geht weiter, für `substitute` und
  `dependsOnNames` auch in allen anderen Templates.
- `components` wird nur geschrieben, wenn etwas ausgewählt ist. Eine leere
  Liste wird `null`, und das lehnt die CRD ab.
- `wait` ist immer `true`: Das Bundle ist erst Ready, wenn jede ausgewählte
  App es ist.
- Ein Formular (`templates/*.yaml`) gibt es für `bundle` noch nicht, weil
  die Parameter Listen und Maps sind.

## Tests

CI (`lint-and-test`) laeuft nur fuer geaenderte Module und prueft
`kcl fmt .`, `kcl lint .`, `kcl run .` sowie die Modulstruktur —
`kcl.mod`, `main.k` und dieses README muessen vorhanden sein.
