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
            package = "xpkg.crossplane.io/crossplane-contrib/provider-helm:v1.3.0"
            clusterRole = "cluster-admin"
        }
        s.Package {
            kind = "Provider"
            name = "upbound-provider-opentofu"
            package = "xpkg.upbound.io/upbound/provider-opentofu:v1.1.4"
            clusterRole = "cluster-admin"
        }
        s.Package {
            kind = "Provider"
            name = "stuttgart-things-provider-kubeconfig-xpkg"
            package = "ghcr.io/stuttgart-things/provider-kubeconfig-xpkg:v0.13.1"
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
            package = "xpkg.upbound.io/crossplane-contrib/function-kcl:v0.12.1"
            apiVersion = "pkg.crossplane.io/v1"
        }
        s.Package {
            kind = "Function"
            name = "function-auto-ready"
            # <v0.7.0 is a hard ceiling: v0.7.0 makes Configurations report
            # Unhealthy and the deploy-crossplane wait times out.
            package = "xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.6.5"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }
        s.Package {
            kind = "Function"
            name = "function-go-templating"
            package = "xpkg.crossplane.io/crossplane-contrib/function-go-templating:v0.12.2"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }
        s.Package {
            kind = "Function"
            name = "function-environment-configs"
            package = "xpkg.crossplane.io/crossplane-contrib/function-environment-configs:v0.7.2"
            apiVersion = "pkg.crossplane.io/v1"
        }
        s.Package {
            kind = "Function"
            name = "function-patch-and-transform"
            package = "xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.10.7"
            apiVersion = "pkg.crossplane.io/v1beta1"
        }

        # --- configurations: ROOTS ONLY --------------------------------------
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-platform"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/platform:v0.3.11"
            pulls = ["cni", "flux-init", "flux-apps", "ip-reservation", "vault-auth", "vault-pki-secrets"]
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-cluster"
            # >=v0.4.0 carries spec.managementPlaneEnabled — without it a
            # management cluster built from this profile cannot build further
            # management clusters, only workload ones.
            package = "ghcr.io/stuttgart-things/crossplane-configurations/cluster:v0.4.0"
            pulls = ["platform", "remote-cluster", "vspherevm", "proxmoxvm", "ansible-run", "management-plane"]
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-vspherevm"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/vspherevm:v0.9.0"
            providerCrd = "clusterproviderconfigs.vspherevm.m.stuttgart-things.com"
            pulls = ["ansible-run"]
        }
        s.Package {
            kind = "Configuration"
            name = "stuttgart-things-crossplane-configurations-proxmoxvm"
            package = "ghcr.io/stuttgart-things/crossplane-configurations/proxmoxvm:v0.11.0"
            pulls = ["ansible-run"]
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
