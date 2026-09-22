import ..schema as s

# machinery — the profile every management cluster in this fleet runs today.
#
# Transcribed from the three places that hold it now, each of which knows part
# of the answer and none of which knows all of it:
#   - stuttgart-things/helm cicd/crossplane*.yaml.gotmpl  (core, providers,
#     functions, provider-configs, two base configurations)
#   - stuttgart-things/ansible kind_machinery.yaml         (the platform and
#     machinery Configuration lists, plus provider-clusterbook)
#   - stuttgart-things/flux cicd/crossplane                (an older generation
#     of the same list, pointing at ghcr.io/stuttgart-things/crossplane/*)
#
# Versions are as of 2026-09-20 and were read from those files, not remembered:
# reconciled against `kind_machinery.yaml`, which is itself kept level with the
# reference clusters (u26-kind3, seed-labda-1). Every pin below is the one the
# play installs; where the two disagreed, the play was right and this file was
# behind — the drift this catalog exists to end runs in that direction, because
# a play is run and a catalog is only read.
#
# 0.7.0 (2026-09-22) was levelled against machinery-kind5 LIVE, not against a
# file: every Provider and root Configuration below is the version kind5 runs
# (32/32 Configurations Healthy), and the providers and function twins the play
# pins explicitly are now pinned here too (flux#506). The short-named Functions
# are the one place this catalog is AHEAD of kind5 (auto-ready, go-templating,
# environment-configs): the play's helm pins lag, and they follow the catalog.
machinery: s.Profile = {
    crossplaneVersion = "2.3.3"
    packages = [
        # --- providers ------------------------------------------------------
        # The long name is deliberate: it is what the package manager derives
        # from the xpkg.crossplane.io path, so an explicit CR and a
        # dependsOn-derived one collapse into one Lock node instead of two
        # providers fighting over the same CRDs.
        s.Package {
            kind = "Provider"
            name = "crossplane-contrib-provider-helm"
            # v1.4.0 hebt das eingebettete Helm-SDK von v3 auf v4. Die
            # Release-API ist unveraendert, das Laufzeitverhalten nicht:
            # Server-Side-Apply ist fuer NEU installierte Releases der Default
            # und `wait` haengt jetzt an kstatus. Durch Release-Objekte geht
            # jede Platform-App (cert-manager, openebs, cni, flux-init) — ein
            # Upgrade hier ist deshalb nie Teil einer reinen CVE-Runde.
            package = "xpkg.crossplane.io/crossplane-contrib/provider-helm:v1.4.0"
            clusterRole = "cluster-admin"
        }
        s.Package {
            kind = "Provider"
            name = "upbound-provider-opentofu"
            package = "xpkg.upbound.io/upbound/provider-opentofu:v1.1.6"
            clusterRole = "cluster-admin"
            # Every reconcile of a Workspace is a full `tofu init/plan/apply`.
            # At the image defaults (poll 10m per resource, sync 1h) six
            # Workspaces held u26-kind3 at load 8 on 8 cores, and
            # kube-controller-manager, kube-scheduler and friends restarted
            # ~3950 times in 39 days because a saturated API server misses lease
            # renewals. Same values as helm cicd/crossplane-providers.yaml.gotmpl.
            env = {
                CROSSPLANE_OPENTOFU_PROVIDER_POLL = "1h"
                CROSSPLANE_OPENTOFU_PROVIDER_SYNC = "6h"
            }
            resources = {
                requests = {cpu = "100m", memory = "256Mi"}
                limits = {cpu = "2", memory = "2Gi"}
            }
        }
        s.Package {
            kind = "Provider"
            name = "stuttgart-things-provider-kubeconfig-xpkg"
            package = "ghcr.io/stuttgart-things/provider-kubeconfig-xpkg:v0.13.2"
        }
        # Not pulled by anything: ip-reservation classes clusterbook as a
        # cluster precondition rather than a package dependency, so without this
        # entry `spec.ipReservation.enabled: true` has no controller behind it.
        s.Package {
            kind = "Provider"
            name = "stuttgart-things-provider-clusterbook-xpkg"
            package = "ghcr.io/stuttgart-things/provider-clusterbook-xpkg:v0.4.2"
            providerCrd = "clusterproviderconfigs.clusterbook.stuttgart-things.com"
        }
        # --- providers that also arrive through dependsOn ---------------------
        # Listed anyway, and that is not the duplicate it looks like: under the
        # DERIVED name an explicit CR and the one the resolver would create are
        # the same Lock node (the rule above). Listing them buys a PIN.
        # Unpinned, a fresh cluster gets whatever the constraint allows that
        # day: u26-kindtest (2026-09-19) came up with provider-kubernetes 1.3.1
        # and proxmox-bpg 1.19.3 next to kind3's 1.2.1 / 1.18.0.
        #
        # THE REGISTRY IS PART OF THE IDENTITY. Each package path below is
        # exactly the one the dependsOn names. "Modernising" one to another
        # mirror gives a second node for the same package and takes every
        # package on the cluster to Healthy=False.
        s.Package {
            kind = "Provider"
            name = "crossplane-contrib-provider-kubernetes"
            # Nearly every Configuration here pulls it (>=v1.2.0,<v2.0.0).
            package = "xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:v1.2.1"
        }
        s.Package {
            kind = "Provider"
            name = "valkiriaaquaticamendi-provider-proxmox-bpg"
            # proxmoxvm pulls it (>=v1.15.0,<v2.0.0).
            package = "xpkg.upbound.io/valkiriaaquaticamendi/provider-proxmox-bpg:v1.18.0"
            # Upjet: every reconcile shells out to terraform with the bpg/proxmox
            # binary. At the default 10m poll and nine Proxmox resources on
            # u26-kind3 that was a terraform run about every 70 seconds, the
            # largest single CPU consumer on that VM. A VM Crossplane itself
            # manages does not drift between polls.
            env = {
                PROVIDER_POLL = "1h"
                PROVIDER_SYNC = "6h"
            }
            resources = {
                requests = {cpu = "100m", memory = "256Mi"}
                limits = {cpu = "2", memory = "2Gi"}
            }
        }
        s.Package {
            kind = "Provider"
            name = "upbound-provider-vault"
            # vault-secrets (through cluster) and vault-k8s-auth (through
            # platform) both depend on it, >=v4.0.4,<v5.0.0 — so it is on every
            # machinery cluster already, only unpinned where nobody pins it.
            #
            # xpkg.upbound.io and NOTHING ELSE: provider-vault is published only
            # there, and it is the path both dependsOn entries name. The same
            # package from xpkg.crossplane.io would be a second Lock node.
            #
            # The package alone is inert: without a vault.m.upbound.io
            # ClusterProviderConfig (credentials per Vault) it reconciles
            # nothing. Those are fleet state, not catalog (stuttgart-things#3136).
            #
            # Runs WITHOUT the poll/sync tuning opentofu and proxmox-bpg get.
            # Deliberate for now: measure once the seeds have moved from
            # OpenTofu to provider-vault (stuttgart-things#3063, #3085), then
            # decide (flux#506).
            package = "xpkg.upbound.io/upbound/provider-vault:v4.0.4"
            providerCrd = "clusterproviderconfigs.vault.m.upbound.io"
        }
        s.Package {
            kind = "Provider"
            name = "vshn-provider-minio"
            # The minio Configuration pulls it (>=v0.4.5,<v0.5.0). Inert without
            # a per-environment minio.crossplane.io ProviderConfig.
            package = "ghcr.io/vshn/provider-minio:v0.4.5"
        }
        # --- functions ------------------------------------------------------
        # SHORT names (root CLAUDE.md) — except the two dependsOn twins, which
        # carry exactly the name the resolver derives (see below). apiVersion is
        # not guessable from the name, hence stated.
        s.Package {
            kind = "Function"
            name = "function-kcl"
            # xpkg.upbound.io, NOT crossplane.io: our dependsOn entries use the
            # crossplane.io path, and the package manager derives a long-named
            # CR from it. Two nodes, two distinct sources — healthy. Aligning
            # the mirrors gives two nodes with an IDENTICAL source and freezes
            # the resolver for every package on the cluster.
            #
            # DIE VERSION IST TEIL DERSELBEN TRENNUNG, nicht nur der Mirror.
            # Der Revision-Name wird aus dem Digest abgeleitet: dieselbe Version
            # auf beiden Mirrors ist DASSELBE Image, also derselbe Suffix. Ein
            # Bump auf v0.12.3 (2026-09-04, Katalog 0.5.0) liess
            # function-kcl-601b48f70f03 und
            # crossplane-contrib-function-kcl-601b48f70f03 entstehen -- ein
            # Knoten zweimal -- und cicd-test4 meldete fuer JEDES Paket
            # "cannot initialize dependency graph from the packages in the lock",
            # bei Installed=True und laufenden Pods. Seit 0.7.0 ist der
            # dependsOn-Knoten selbst gepinnt (crossplane-contrib-function-kcl
            # unten, v0.12.2 wie auf kind5). Dieser Pin bleibt auf v0.12.2, bis
            # der cicd-test4-Vorfall verstanden ist -- siehe dort.
            package = "xpkg.upbound.io/crossplane-contrib/function-kcl:v0.12.2"
            apiVersion = "pkg.crossplane.io/v1"
        }
        # The dependsOn twin, pinned. Every Configuration names function-kcl on
        # xpkg.crossplane.io, so the resolver creates this CR on every cluster
        # anyway — the only question is at which version. Unpinned, u26-kindtest
        # got 0.12.3 against kind3's 0.12.2.
        #
        # Named EXACTLY as the resolver names it, on EXACTLY its registry: that
        # is what makes this the dependsOn node rather than a third one.
        #
        # Same version as the short entry above, deliberately, because that is
        # what kind5 runs: both at v0.12.2, both revisions ending in the same
        # digest suffix (8faf0d7c4631), both Healthy (2026-09-22). So "same
        # digest on both mirrors" is NOT by itself the cicd-test4 collision
        # recorded above — the revision names still differ by their prefix. The
        # short pin stays at v0.12.2 regardless until that incident is
        # understood.
        s.Package {
            kind = "Function"
            name = "crossplane-contrib-function-kcl"
            package = "xpkg.crossplane.io/crossplane-contrib/function-kcl:v0.12.2"
            apiVersion = "pkg.crossplane.io/v1"
        }
        s.Package {
            kind = "Function"
            name = "function-auto-ready"
            # <v0.7.0 bleibt eine harte Decke, und der Grund ist praeziser
            # als "v0.7.0 ist kaputt": 30 Stellen in crossplane-configurations
            # deklarieren dependsOn function-auto-ready >=v0.6.5,<v0.7.0. Mit
            # v0.7.0 melden diese Package-Revisions "incompatible dependencies"
            # und der deploy-crossplane-Wait laeuft in den Timeout. Erst
            # anheben, wenn die Configurations die Spanne weiten.
            #
            # v0.6.8 statt v0.6.5 (zuletzt 2026-09-04): die 0.6er-Linie lebt
            # WEITER, v0.6.6 bis v0.6.8 sind NACH v0.7.0 erschienen und sind
            # reine CVE-Backports (Go 1.25.12, x/net, x/text, grpc). Unter der
            # Decke zu bleiben heisst also nicht, auf Sicherheitsfixes zu
            # verzichten. Der catalog-parity-Check sieht das nicht: er
            # vergleicht gegen das hoechste Semver und zeigt deshalb auf das
            # verbotene v0.7.0 -- v0.6.8 IST hier das Neueste, das geht.
            package = "xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.6.8"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }
        s.Package {
            kind = "Function"
            name = "function-go-templating"
            package = "xpkg.crossplane.io/crossplane-contrib/function-go-templating:v0.12.4"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }
        s.Package {
            kind = "Function"
            name = "function-environment-configs"
            package = "xpkg.crossplane.io/crossplane-contrib/function-environment-configs:v0.7.4"
            apiVersion = "pkg.crossplane.io/v1"
        }
        s.Package {
            kind = "Function"
            name = "function-patch-and-transform"
            # v0.10.9, NICHT v0.10.10: die 0.10.10 ist auf xpkg.upbound.io
            # nicht veroeffentlicht (list-tags endet bei v0.10.9), nur der
            # Pull-Through loest sie auf -- catalog-parity faengt das ab.
            # Auf xpkg.crossplane.io gaebe es sie, aber der Mirror ist hier
            # kein Detail: ein Wechsel kann denselben Source-String erzeugen
            # wie ein dependsOn-abgeleiteter Knoten, und zwei Knoten mit
            # IDENTISCHER Quelle frieren den Resolver fuer den ganzen Cluster
            # ein. Also das Neueste, das dieser Mirror wirklich hat.
            package = "xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.10.9"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }
        # The dependsOn twin, for the same reason as crossplane-contrib-function-kcl
        # above. v0.10.8, what kind5 runs; unpinned, u26-kindtest got 0.10.11.
        s.Package {
            kind = "Function"
            name = "crossplane-contrib-function-patch-and-transform"
            package = "xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.10.8"
            apiVersion = "pkg.crossplane.io/v1"
        }
        # --- configurations: ROOTS ONLY --------------------------------------
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-platform"
            # v0.6.2, nicht v0.3.11: der Katalog war gegenueber dem
            # Referenz-Cluster u26-kind3 vier Configurations weit
            # zurueckgefallen (2026-08-20 abgeglichen). Ein Profil, das
            # beschreibt, was eine Machinery IST, darf das nicht.
            #
            # v0.7.2 (2026-09-20 abgeglichen gegen kind_machinery.yaml, das
            # seinerseits u26-kind3 nachgezogen hat): gebundene ServiceAccounts
            # fuer zusaetzliche Vault-Auths, clusterSecrets (der Cluster-eigene
            # Observability-Eintrag), cni.gatewayAPI-Durchreichung, kein
            # generiertes Webhook-Token. FLOORS UNVERAENDERT — vault-pki-secrets
            # bleibt >=v0.1.5, das ist also NICHT der "raised floor"-Fall, der
            # einen bestehenden Cluster von Hand nachziehen laesst.
            #
            # v0.8.0 (kind5, ansible#1241): spec.vaultIssuer.authProvider can
            # drive Vault through provider-vault. NEW dependsOn vault-k8s-auth
            # >=v0.4.2,<v0.5.0, which pulls upbound-provider-vault. Fresh
            # clusters resolve it; nothing to raise by hand.
            package = "ghcr.io/stuttgart-things/crossplane-configurations/platform:v0.8.0"
            pulls = ["cni", "flux-init", "flux-apps", "ip-reservation", "vault-auth", "vault-k8s-auth", "vault-pki-secrets"]
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-cluster"
            # >=v0.4.0 carries spec.managementPlaneEnabled — without it a
            # management cluster built from this profile cannot build further
            # management clusters, only workload ones.
            #
            # v0.6.1 ist aus demselben Grund ein Muss, eine Ebene weiter: erst
            # v0.6.0 kennt `harvester` im Provider-Enum und erst v0.6.1 das
            # Vault-Paar vault-labda -> vault-kubeconfigs-labda. Ein Seed auf
            # v0.4.0 kann also genau die LabDA-Cluster NICHT bauen, fuer die er
            # aufgestellt wird — aufgefallen beim ersten LabDA-Seed
            # (crossplane-configurations#258, 2026-08-20).
            #
            # v0.11.5, und der Sprung ueber fuenf Minors ist genau das Problem,
            # das der Katalog abstellen soll: u26-kind3 lief schon auf v0.10.0,
            # waehrend dieser Pin noch v0.6.1 sagte — ein Re-Apply haette das
            # Paket HERUNTERGESTUFT und die XRD zurueckgeschrumpft (kein
            # rancher-Provisioner, keine profiles, keine secretStores),
            # stuttgart-things#3013. `kubectl apply` laeuft eine Configuration
            # rueckwaerts ohne zu klagen; DIESEN PIN NIE SENKEN.
            #
            #   v0.10.0  rancher-rke2-Provisioner (RancherCluster-Kind, join
            #            stage), Vault-Kubeconfig-Workspace, profiles + abgeleitete
            #            Argo-CD-Labels. ANGEHOBENER FLOOR: dependsOn
            #            rancher-cluster >=v0.8.1 und function-environment-configs.
            #            Frische Cluster loesen das auf; ein bereits installiertes
            #            aelteres rancher-cluster muss von Hand nachgezogen werden.
            #   v0.11.0  App-Secrets aus AppSecretProfiles
            #            (crossplane-configurations#464/#470), neue dependsOn
            #            vault-secrets >=v0.4.0 und app-secret-profile >=v0.1.0.
            #   v0.11.4  v0.11.0/v0.11.1 trugen eine CEL-Regel, deren geschaetzte
            #            Kosten das API-Server-Budget sprengen: die ClusterStack-CRD
            #            liess sich nicht mehr aktualisieren und nach einem
            #            Crossplane-Neustart reconcilete KEIN ClusterStack mehr
            #            (crossplane-configurations#473). v0.11.2 und v0.11.3 sind
            #            v0.11.1-Inhalt — diese drei nie pinnen.
            #   v0.11.5  xplane-cluster 0.19.0 (crossplane-configurations#474).
            #   v0.11.10 what u26-kind3 and kind5 run (ansible#1245). dependsOn
            #            floors unchanged against v0.11.5.
            package = "ghcr.io/stuttgart-things/crossplane-configurations/cluster:v0.11.10"
            pulls = [
                "platform"
                "remote-cluster"
                "rancher-cluster"
                "vspherevm"
                "proxmoxvm"
                "ansible-run"
                "management-plane"
                "vault-secrets"
                "app-secret-profile"
            ]
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-vspherevm"
            # v0.9.2 NICHT v0.9.0: v0.9.0 reicht spec.environmentConfig an die
            # emittierte AnsibleRun durch. Das benennt eine Hypervisor-Env, die
            # ansible-run gegen sein EIGENES Label aufloest, wo es sie nicht
            # gibt — jeder ansible-run-Default faellt still weg,
            # ansibleExtraCollections eingeschlossen, und der Base-OS-Lauf
            # scheitert an einer Collection-Version. crossplane-configurations#347.
            #
            # v0.10.0 bringt spec.vm.cloneDatastore, v0.11.0 dessen `none`-
            # Opt-out. Fuer LabUL nicht optional: beide Base-OS-Templates halten
            # ihre Disk auf dem NFS-Store DD-sthings, dessen ACL Anfang 2026-08
            # Datastore.AllocateSpace verloren hat — ein Clone, der kein
            # Ziel-Datastore benennen kann, laeuft in ein 403. Unterhalb v0.10.0
            # kennt die XRD das Feld gar nicht, und jedes Paket meldet trotzdem
            # Healthy.
            #
            # v0.12.0: what kind5 runs. Still provider-vspherevm-xpkg
            # >=v0.8.1,<v0.9.0 and ansible-run >=v0.1.4.
            package = "ghcr.io/stuttgart-things/crossplane-configurations/vspherevm:v0.12.0"
            providerCrd = "clusterproviderconfigs.vspherevm.m.stuttgart-things.com"
            pulls = ["ansible-run"]
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-proxmoxvm"
            # v0.12.0 trennt templateNode vom Ziel-Node, v0.12.2 nimmt denselben
            # environmentConfig-Durchreicher heraus wie vspherevm v0.9.2 oben
            # (crossplane-configurations#347), v0.13.0 macht den
            # cloud-init-Datastore ueber die EnvironmentConfig setzbar
            # (crossplane-configurations#350).
            #
            # v0.15.0 ist der Stand, den kind_machinery.yaml auf jede Machinery
            # legt (2026-09-20 abgeglichen). Was v0.14.0 und v0.15.0 im
            # Einzelnen aendern, steht in crossplane-configurations, nicht hier;
            # kind_machinery.yaml notiert zu keinem der beiden einen neuen
            # dependsOn-Floor.
            #
            # v0.16.0: what kind5 runs. Still provider-proxmox-bpg
            # >=v1.15.0,<v2.0.0 and ansible-run >=v0.1.4.
            package = "ghcr.io/stuttgart-things/crossplane-configurations/proxmoxvm:v0.16.0"
            pulls = ["ansible-run"]
        }
        # Dritter Hypervisor neben vSphere und Proxmox. Stand im Profil bisher
        # gar nicht, obwohl das machinery-Playbook ihn auf jeden Machinery-
        # Cluster legt — der Katalog beschrieb also eine Machinery, die es so
        # nicht gibt.
        #
        # KEIN providerCrd, und das ist kein Versehen: harvester-vm rendert eine
        # KubeVirt VirtualMachine ueber provider-kubernetes und registriert
        # keinen eigenen Provider.
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-harvester-vm"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/harvester-vm:v0.1.12"
            pulls = ["volume-claim", "cloud-config", "ansible-run"]
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-packer-build"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/packer-build:v0.4.1"
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-packer-release"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/packer-release:v0.4.2"
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-cluster-backup"
            # Das Paket allein macht die Faehigkeit verfuegbar; ein laufendes
            # Backup braucht zusaetzlich das Push-Secret der Backup-Registry und
            # — bei eingeschraenkter Provider-SA — die provider-kubernetes-RBAC
            # aus dem README der Configuration. Beides ist Cluster-Fakt und
            # steht deshalb nicht hier.
            package = "ghcr.io/stuttgart-things/crossplane-configurations/cluster-backup:v0.2.0"
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-scheduled-run"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/scheduled-run:v0.1.1"
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-tofu-run"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/tofu-run:v0.1.0"
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-namespace"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/namespace:v0.1.2"
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-volume-claim"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/volume-claim:v0.1.0"
        }
        # Nothing pulls minio: it is on kind5 because the play installs it, and a
        # machinery cluster rebuilt from this catalog did not have it (flux#506).
        # Buckets need a per-environment minio.crossplane.io ProviderConfig with
        # admin keys — cluster fact, not here.
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-minio"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/minio:v0.1.0"
        }
        # capability und argocd-cluster: NICHTS zieht die beiden ueber dependsOn,
        # sie existieren also nur dort, wo jemand sie installiert. Auf u26-kind3
        # war das von Hand (2026-08-17/18), jeweils mit einem lebenden XR
        # (seed-labda-1-capability, homerun2-test1) — und genau deshalb fielen
        # sie hier nicht auf. Ein aus Git neu gebauter Machinery-Cluster hatte
        # beide XRDs nicht (u26-kindtest-Rebuild, 2026-09-19).
        #
        # Das ist der Fall, fuer den dieser Katalog existiert: was eine Machinery
        # IST, darf nicht davon abhaengen, was jemand einmal per kubectl
        # nachgelegt hat.
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-capability"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/capability:v0.7.2"
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-argocd-cluster"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/argocd-cluster:v0.2.1"
        }
    ]
    # Point each provider at the cluster it runs on. No credentials: the
    # provider's own ServiceAccount is the identity.
    providerConfigs = [
        s.ProviderConfig {
            name = "in-cluster"
            apiVersion = "helm.m.crossplane.io/v1beta1"
            kind = "ClusterProviderConfig"
            spec = {
                credentials = {source = "InjectedIdentity"}
            }
        }
        s.ProviderConfig {
            name = "in-cluster"
            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
            kind = "ClusterProviderConfig"
            spec = {
                credentials = {source = "InjectedIdentity"}
            }
        }
        # OpenTofu keeps its state in Secrets on this cluster, so a rebuilt
        # control plane does not orphan what it provisioned.
        s.ProviderConfig {
            name = "in-cluster"
            apiVersion = "opentofu.m.upbound.io/v1beta1"
            kind = "ClusterProviderConfig"
            spec = {
                credentials = []
                configuration = """terraform {
  backend "kubernetes" {
    secret_suffix     = "clusterproviderconfig-in-cluster"
    namespace         = "crossplane-system"
    in_cluster_config = true
  }
}
"""
            }
        }
    ]
}
