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
# Versions are as of 2026-08-15 and were read from those files, not remembered.

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
        # provider-kubernetes is absent ON PURPOSE — every Configuration below
        # pulls it, and naming it here would create the duplicate this catalog
        # exists to prevent.

        # --- functions ------------------------------------------------------
        # SHORT names, always (root CLAUDE.md). apiVersion is not guessable from
        # the name, hence stated.
        s.Package {
            kind = "Function"
            name = "function-kcl"
            # xpkg.upbound.io, NOT crossplane.io: our dependsOn entries use the
            # crossplane.io path, and the package manager derives a long-named
            # CR from it. Two nodes, two distinct sources — healthy. Aligning
            # the mirrors gives two nodes with an IDENTICAL source and freezes
            # the resolver for every package on the cluster.
            package = "xpkg.upbound.io/crossplane-contrib/function-kcl:v0.12.2"
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
            # v0.6.7 statt v0.6.5 (2026-08-21): die 0.6er-Linie lebt WEITER,
            # v0.6.6 und v0.6.7 sind NACH v0.7.0 erschienen und sind reine
            # CVE-Backports (Go 1.25.12, x/net, x/text, grpc). Unter der Decke
            # zu bleiben heisst also nicht, auf Sicherheitsfixes zu verzichten.
            # Der catalog-parity-Check sieht das nicht: er vergleicht gegen das
            # hoechste Semver und zeigte deshalb auf das verbotene v0.7.0.
            package = "xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.6.7"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }
        s.Package {
            kind = "Function"
            name = "function-go-templating"
            package = "xpkg.crossplane.io/crossplane-contrib/function-go-templating:v0.12.3"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }
        s.Package {
            kind = "Function"
            name = "function-environment-configs"
            package = "xpkg.crossplane.io/crossplane-contrib/function-environment-configs:v0.7.3"
            apiVersion = "pkg.crossplane.io/v1"
        }
        s.Package {
            kind = "Function"
            name = "function-patch-and-transform"
            package = "xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.10.9"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }

        # --- configurations: ROOTS ONLY --------------------------------------
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-platform"
            # v0.6.2, nicht v0.3.11: der Katalog war gegenueber dem
            # Referenz-Cluster u26-kind3 vier Configurations weit
            # zurueckgefallen (2026-08-20 abgeglichen). Ein Profil, das
            # beschreibt, was eine Machinery IST, darf das nicht.
            package = "ghcr.io/stuttgart-things/crossplane-configurations/platform:v0.6.2"
            pulls = ["cni", "flux-init", "flux-apps", "ip-reservation", "vault-auth", "vault-pki-secrets"]
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
            package = "ghcr.io/stuttgart-things/crossplane-configurations/cluster:v0.6.1"
            pulls = ["platform", "remote-cluster", "vspherevm", "proxmoxvm", "ansible-run", "management-plane"]
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
            package = "ghcr.io/stuttgart-things/crossplane-configurations/vspherevm:v0.9.2"
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
            package = "ghcr.io/stuttgart-things/crossplane-configurations/proxmoxvm:v0.13.0"
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
            package = "ghcr.io/stuttgart-things/crossplane-configurations/harvester-vm:v0.1.9"
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
            package = "ghcr.io/stuttgart-things/crossplane-configurations/cluster-backup:v0.1.0"
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
    ]
    # Point each provider at the cluster it runs on. No credentials: the
    # provider's own ServiceAccount is the identity.
    providerConfigs = [
        s.ProviderConfig {
            name = "in-cluster"
            apiVersion = "helm.m.crossplane.io/v1beta1"
            kind = "ClusterProviderConfig"
            spec = {credentials = {source = "InjectedIdentity"}}
        }
        s.ProviderConfig {
            name = "in-cluster"
            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
            kind = "ClusterProviderConfig"
            spec = {credentials = {source = "InjectedIdentity"}}
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
