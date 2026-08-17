# Unit tests for the catalog. Run with `kcl test`.
# These validate the catalog's own invariants — no Crossplane, no cluster.
import .main as c

test_dapr_is_registered = lambda {
    assert "dapr" in c.catalog
    assert c.catalog.dapr.artifact == "oci://ghcr.io/stuttgart-things/flux/apps/dapr"
}

test_get_returns_app = lambda {
    assert c.get("dapr").defaultVersion == "v1.18.1"
}

# Every dependsOn must resolve to a component that actually exists — either a
# sibling in the same app, or "app:component" in another app. A typo would
# otherwise surface only as a Kustomization stuck in DependencyNotReady on a
# live cluster, which is a slow and confusing way to find it.
_depApp = lambda owner: str, dep: str -> str {
    dep.split(":")[0] if ":" in dep else owner
}
_depComponent = lambda dep: str -> str {
    dep.split(":")[1] if ":" in dep else dep
}

test_dependson_targets_exist = lambda {
    assert all _n, app in c.catalog {
        all comp in app.components {
            all dep in comp.dependsOn {
                _depApp(_n, dep) in c.catalog and _depComponent(dep) in [x.name for x in c.catalog[_depApp(_n, dep)].components]
            }
        }
    }, "a dependsOn entry names a component that does not exist"
}

# The first cross-artifact dependency: trust-manager cannot reconcile before
# cert-manager's CRDs exist.
test_cross_artifact_dependson = lambda {
    tm = c.get("trust-manager").components[0]
    assert tm.dependsOn == ["cert-manager:install"]
    assert "install" in [x.name for x in c.get("cert-manager").components]
}

# Component names must be unique within an app; duplicates would collide on the
# emitted Kustomization name '{app}-{component}'.
test_component_names_unique = lambda {
    assert all _n, app in c.catalog {
        len([x.name for x in app.components]) == len({x.name: "" for x in app.components})
    }, "component names must be unique within an app"
}

# Anything wrapping a HelmRelease needs a raised timeout — the 10m FluxApps
# default was demonstrably too short for dapr's chart install.
test_helmrelease_components_raise_timeout = lambda {
    assert all _n, app in c.catalog {
        all comp in app.components {
            not comp.wrapsHelmRelease or comp.timeout != Undefined
        }
    }, "a component that wraps a HelmRelease must raise its timeout"
}

test_headlamp_is_registered = lambda {
    h = c.get("headlamp")
    assert h.artifact == "oci://ghcr.io/stuttgart-things/flux/apps/headlamp"
    assert len(h.components) == 1
    assert h.components[0].path == "./", "single-component apps reconcile the artifact root"
}

# Vars without a manifest default must be declared, or Flux substitutes an empty
# string and deploys something silently broken.
test_headlamp_declares_required_substitutions = lambda {
    assert c.get("headlamp").components[0].requiredSubstitutions == ["DOMAIN", "HOSTNAME", "GATEWAY_NAME"]
}

# Opt-in extras must not default to enabled: cert-manager's selfsigned issuer
# needs a domain, and requiring it just to install cert-manager would be wrong.
test_optional_components_are_marked = lambda {
    cm = {x.name: x for x in c.get("cert-manager").components}
    assert not cm["install"].optional, "the base install is not optional"
    assert cm["selfsigned"].optional
}

# openebs declares no REQUIRED substitutions — every variable in its manifests
# carries a `${VAR:-default}` fallback.
#
# THAT IS A STATEMENT ABOUT THE CATALOG, NOT ABOUT USAGE, and the distinction
# cost a live debug on u26-rke2-1 (2026-08-12). An XR still has to supply a
# `substitute` block: xplane-flux-apps used to emit `postBuild` only when one
# was present, and kustomize-controller runs its substitution pass only when
# spec.postBuild is non-nil — so a bare enable meant NO substitution at all and
# the fallbacks never applied. `${OPENEBS_NAMESPACE:-openebs}` reached the
# cluster as a literal string and failed namespace validation.
#
# Fixed in xplane-flux-apps 0.2.0, which always emits postBuild. The test name
# stays about the catalog on purpose — it was previously called
# `test_openebs_needs_no_substitutions`, which read as a promise about usage.
test_openebs_declares_no_required_substitutions = lambda {
    _a = c.get("openebs")
    assert len(_a.components) == 1
    assert _a.components[0].requiredSubstitutions == []
    assert _a.components[0].dependsOn == []
    assert _a.components[0].path == "./"
    assert _a.components[0].wrapsHelmRelease
}

# The catalog version is the FLUX ARTIFACT tag, never the openebs chart version
# (which the artifact pins separately as OPENEBS_VERSION, default 4.2.0). Two
# floors, both load-bearing:
#
#   v1.19.1  first release carrying flux#192 — before it the artifact had no
#            loki/alloy keys, so raising OPENEBS_VERSION to 4.5.x would have
#            silently deployed Loki, MinIO and Alloy with no way to say no.
#   v1.20.1  makes openebs-hostpath the DEFAULT StorageClass (flux#198). rke2
#            ships no default at all, so a cluster could install openebs and
#            still have every unclassed PVC hang. Found through Tekton: its
#            Results component wants a PostgreSQL, the PVC stayed Pending, the
#            operator blocked, and the Dashboard never appeared — a failure
#            that named neither storage nor a class.
test_openebs_pins_a_release_that_can_say_no_to_loki = lambda {
    _v = c.get("openebs").defaultVersion
    assert _v.startswith("v")
    assert _v != "v4.2.0", "the artifact tag, not the chart version"
    assert _v == "v1.20.1"
}

test_cilium_is_registered = lambda {
    _c = c.get("cilium")
    assert _c.artifact == "oci://ghcr.io/stuttgart-things/flux/infra/cilium"
    assert len(_c.components) == 1
    assert _c.components[0].path == "./", "the artifact root is lb + gateway"
}

# The four variables the lb and gateway manifests use WITHOUT a `:=` default.
# Flux substitutes an empty string for a missing one, and both offenders apply
# cleanly: an IP pool with blank bounds and a Gateway with a blank hostname are
# valid objects that do nothing. Declared so a consumer can reject the app
# before it deploys something that merely looks healthy.
test_cilium_declares_required_substitutions = lambda {
    assert c.get("cilium").components[0].requiredSubstitutions == [
        "CILIUM_LB_IP_START"
        "CILIUM_LB_IP_STOP"
        "CILIUM_GATEWAY_DOMAIN"
        "CILIUM_GATEWAY_TLS_SECRET"
        "CILIUM_GATEWAY_NAME"
    ]
}

# CILIUM_GATEWAY_NAME is the odd one out: the artifact DOES default it
# (`${CILIUM_GATEWAY_NAME:-cilium-gateway}`), so leaving it unset would be
# harmless. It is required anyway, because required-and-sourced is the only
# combination this catalog allows — a source without a requirement would make a
# typo in the source path invisible. The source always resolves (the platform
# defaults the name), so requiring it costs nothing.
test_cilium_gateway_name_is_required_only_to_be_sourced = lambda {
    _c = c.get("cilium").components[0]
    assert _c.substitutionSources["CILIUM_GATEWAY_NAME"] == "gateway.name"
    assert "CILIUM_GATEWAY_NAME" in _c.requiredSubstitutions

    # The same fact reaches the Gateway that CREATES it and every app that
    # merely REFERENCES it, so a rename can never desynchronise the two.
    assert c.get("machinery").components[0].substitutionSources["GATEWAY_NAME"] == "gateway.name"
    assert c.get("headlamp").components[0].substitutionSources["GATEWAY_NAME"] == "gateway.name"
}

# cilium is CONFIG-ONLY and must stay that way. The artifact ships a
# `components/install` beside lb and gateway which the root does not reference,
# because every target cluster already runs Cilium as its CNI — a second
# install would be two CNIs on one datapath. An `install` component appearing
# here would mean someone wired that path into the platform.
#
# It also has no dependsOn: its real prerequisite (Cilium running with Gateway
# API and L2 announcements enabled) is a cluster fact the rke2 role provides,
# not another catalog app.
test_cilium_is_config_only = lambda {
    _c = c.get("cilium")
    assert "install" not in [x.name for x in _c.components], "cilium must not install a second CNI"
    assert _c.components[0].name == "config"
    assert _c.components[0].dependsOn == []
    assert not _c.components[0].wrapsHelmRelease
}

# The three cilium variables that are FACTS the platform discovers, mapped to
# where it can read them. Repeating them on the XR is how they drift: when the
# reservation moved to a platform child on u26-rke2-1 the IP changed .5 -> .8,
# DNS followed and the Gateway did not.
test_cilium_declares_substitution_sources = lambda {
    _src = c.get("cilium").components[0].substitutionSources
    assert _src["CILIUM_GATEWAY_DOMAIN"] == "ipReservation.domain"
    # count: 1 reserves ONE address; the pool is that address, not a range.
    assert _src["CILIUM_LB_IP_START"] == "ipReservation.ipAddresses[0]"
    assert _src["CILIUM_LB_IP_STOP"] == _src["CILIUM_LB_IP_START"]
}

# TLS_SECRET must never gain a source: it is a decision about where a
# certificate is issued, not a fact the platform can discover.
test_cilium_tls_secret_stays_manual = lambda {
    _c = c.get("cilium").components[0]
    assert "CILIUM_GATEWAY_TLS_SECRET" in _c.requiredSubstitutions
    assert "CILIUM_GATEWAY_TLS_SECRET" not in _c.substitutionSources
}

# Every source must belong to a variable the component actually declares —
# a typo would otherwise resolve nothing and be invisible until deploy.
test_substitution_sources_name_declared_variables = lambda {
    assert all _n, app in c.catalog {
        all comp in app.components {
            all v in comp.substitutionSources {
                v in comp.requiredSubstitutions
            }
        }
    }, "a substitutionSources key names a variable the component does not declare"
}

# headlamp's DOMAIN is the cluster domain — discoverable, and the same value the
# Gateway listener wildcard and the certificate CN come from. GATEWAY_NAME is
# discovered too now: the platform publishes the name it also creates the
# Gateway with. HOSTNAME stays manual — what a service is CALLED is a decision,
# not a fact about the cluster.
test_headlamp_discovers_domain_and_gateway = lambda {
    _c = c.get("headlamp").components[0]
    assert _c.substitutionSources == {DOMAIN = "ipReservation.domain", GATEWAY_NAME = "gateway.name"}
    assert "HOSTNAME" not in _c.substitutionSources, "the name is a decision"

    # Still REQUIRED, and that is the point: required-and-discovered is what
    # makes a component defer until the value exists (#277) instead of
    # deploying with a blank Flux would substitute without complaint.
    assert "GATEWAY_NAME" in _c.requiredSubstitutions
    _typed = [v for v in _c.requiredSubstitutions if v not in _c.substitutionSources]
    assert _typed == ["HOSTNAME"], "only the name is still typed"
}

# The machinery SERVICE, not the bootstrap play of the same name. Enabling it
# now costs NO typed value at all: DOMAIN comes from the reservation, the
# Gateway's name from the platform that creates it. That is the payoff of
# substitutionSources, and the assertion is here so a later artifact change
# adding a required variable is noticed.
test_machinery_costs_no_typed_value = lambda {
    _c = c.get("machinery").components[0]
    assert _c.requiredSubstitutions == ["DOMAIN", "GATEWAY_NAME"]
    assert _c.substitutionSources == {DOMAIN = "ipReservation.domain", GATEWAY_NAME = "gateway.name"}
    _typed = [v for v in _c.requiredSubstitutions if v not in _c.substitutionSources]
    assert _typed == [], "a bare enable is now enough"

    # MACHINERY_VERSION was required until stuttgart-things/flux#193 fixed the
    # artifact's `1.13.4` default (published tags read `v1.13.4`). It must stay
    # out: re-adding it would mean the artifact's default broke again.
    assert "MACHINERY_VERSION" not in _c.requiredSubstitutions
}

# external-secrets is the entry that unblocks the others: with a
# ClusterSecretStore standing, an app can reference an ExternalSecret instead of
# carrying a password. Substitutions land in postBuild.substitute — the XR spec,
# and therefore git in the clear — which is why harbor, kube-prometheus-stack
# and argo-cd are not catalogued yet.
test_external_secrets_has_an_optional_vault_store = lambda {
    _c = {x.name: x for x in c.get("external-secrets").components}
    assert not _c["install"].optional, "ESO itself is not optional"
    assert _c["install"].wrapsHelmRelease
    assert _c["cluster-store-vault"].optional, "a cluster may want a different backend, or none yet"
    assert _c["cluster-store-vault"].dependsOn == ["install"]
    # Five are required despite the artifact defaulting every one — see below.
    assert _c["cluster-store-vault"].requiredSubstitutions == [
        "VAULT_K8S_AUTH_MOUNT_PATH"
        "VAULT_K8S_AUTH_ROLE"
        "VAULT_CSS_NAME"
        "VAULT_KV_PATH"
        "VAULT_K8S_AUTH_SA_NAME"
    ]
}

# The wiring that was missing until xplane-platform 0.14.0: the mount path and
# role come from the vaultIssuer that CREATED them, not from the artifact's
# defaults — which describe one specific cluster (mount `platform-sthings-eso`,
# role `eso`) and would have a second cluster authenticate against the wrong
# mount, or against nothing.
test_external_secrets_discovers_its_vault = lambda {
    _c = {x.name: x for x in c.get("external-secrets").components}
    _src = _c["cluster-store-vault"].substitutionSources
    assert _src["VAULT_K8S_AUTH_MOUNT_PATH"] == "vaultIssuer.auths.eso.mountPath"
    assert _src["VAULT_K8S_AUTH_ROLE"] == "vaultIssuer.auths.eso.role"
}

# Keyed by auth NAME, never by index. spec.vaultIssuer.additionalAuths is a
# list, and an indexed path would silently point at cert-manager's mount the
# moment someone reorders it — handing a secrets reader a certificate-issuing
# role, which is exactly the mix-up the separate auth exists to prevent.
test_external_secrets_addresses_the_auth_by_name = lambda {
    _c = {x.name: x for x in c.get("external-secrets").components}
    _paths = [v for _, v in _c["cluster-store-vault"].substitutionSources]
    assert len([p for p in _paths if "[" in p]) == 0, "an index would break on reorder"
    assert len([p for p in _paths if ".eso." in p]) == len(_paths)
}

# Both nfs-csi variables are facts about the NETWORK the cluster sits in, not
# about the cluster — nothing in the platform's status can discover them.
test_nfs_csi_needs_the_export_named = lambda {
    _c = c.get("nfs-csi").components[0]
    assert _c.requiredSubstitutions == ["NFS_SERVER_FQDN", "NFS_SHARE_PATH"]
    assert _c.substitutionSources == {}
    assert _c.path == "./"
}

# vault installs a Vault ON the cluster. It is NOT the fleet's Vault at
# vault.infra.sthings-vsphere, which platform.vaultIssuer consumes rather than
# manages — the names collide in conversation more than in configuration.
#
# Notably it needs no admin password, unlike harbor or argo-cd: Vault
# initialises itself and unsealing is the autounseal component's job.
test_vault_needs_no_password = lambda {
    _a = c.get("vault")
    assert _a.artifact.endswith("/apps/vault")
    _all = [v for x in _a.components for v in x.requiredSubstitutions]
    assert len([v for v in _all if "PASSWORD" in v or "TOKEN" in v]) == 0
    _c = {x.name: x for x in _a.components}
    assert _c["autounseal"].optional, "a Vault that unseals itself is a trade-off, not a default"
    assert _c["httproute"].optional
}

# The domain is discovered, the issuer is not: which Issuer a certificate comes
# from is a decision about trust, and no status field can make it.
test_vault_discovers_the_domain_but_not_the_issuer = lambda {
    _c = {x.name: x for x in c.get("vault").components}
    assert _c["install"].substitutionSources["VAULT_INGRESS_DOMAIN"] == "ipReservation.domain"
    assert "ISSUER_NAME" not in _c["install"].substitutionSources
    assert "ISSUER_KIND" not in _c["install"].substitutionSources
    assert _c["httproute"].substitutionSources["VAULT_DOMAIN"] == "ipReservation.domain"
}

# Every optional component that depends on another must name one that exists —
# already covered generically, asserted here for the four added at once so a
# typo in this batch fails loudly rather than as DependencyNotReady on a
# cluster.
test_new_entries_are_registered = lambda {
    _want = ["external-secrets", "nfs-csi", "vault", "tekton", "sops-secrets-operator"]
    _missing = [n for n in _want if n not in c.catalog]
    assert _missing == [], "entry missing from the registry"
    assert len(c.names) == 12
}

# Both depend on cert-manager, and both would present as something else without
# it. trust-manager's CRDs never appear; the sops operator's Deployment comes up
# healthy and every SopsSecret apply is then rejected by a validating webhook
# whose certificate was never issued — which reads like a broken CRD.
test_webhook_apps_depend_on_cert_manager = lambda {
    _detached = [
        n
        for n in ["trust-manager", "sops-secrets-operator"]
        if "cert-manager:install" not in c.get(n).components[0].dependsOn
    ]
    assert _detached == [], "must wait for cert-manager: " + str(_detached)
}

# No HelmRelease here: the app pulls a kustomize base built from the operator's
# own config/default, so there is no chart to wait on. The assertion is here
# because wrapsHelmRelease also drives the default timeout, and a later editor
# copying trust-manager wholesale would set it wrongly.
test_sops_operator_is_not_a_helm_release = lambda {
    _c = c.get("sops-secrets-operator").components[0]
    assert not _c.wrapsHelmRelease
    assert _c.requiredSubstitutions == [], "the age key is not a substitution"
}

# tekton is the first entry from cicd/ rather than apps/ or infra/ — those were
# the only directories the flux release workflow published, so nothing under
# cicd/ existed as an OCI artifact until stuttgart-things/flux#196.
test_tekton_is_split_so_only_the_dashboard_costs_a_value = lambda {
    _c = {x.name: x for x in c.get("tekton").components}
    assert sorted(_c) == ["ci-namespace", "dashboard", "install"]

    # The point of splitting: operator and config need nothing, the namespace
    # defaults its own. Bundled, every Tekton user would owe a domain whether or
    # not they wanted a dashboard — and Flux substitutes an empty string rather
    # than failing, so they would get a route pointing at nothing.
    assert _c["install"].requiredSubstitutions == []
    assert _c["ci-namespace"].requiredSubstitutions == []
    assert "TEKTON_DASHBOARD_DOMAIN" in _c["dashboard"].requiredSubstitutions

    # Only the dashboard is a choice. The CI namespace is ON by default although
    # upstream calls it opt-in: every Tekton here runs Crossplane-managed
    # PipelineRuns, and that namespace carries the prune.skip annotation which
    # keeps the cluster-wide pruner from deleting them overnight.
    assert _c["dashboard"].optional
    assert not _c["ci-namespace"].optional
    assert not _c["install"].optional
}

# Of the dashboard's three required variables only the hostname is typed — what
# a service is CALLED is a decision. Domain and Gateway name are facts the
# platform already publishes.
test_tekton_dashboard_costs_one_typed_value = lambda {
    _d = [x for x in c.get("tekton").components if x.name == "dashboard"][0]
    _typed = [v for v in _d.requiredSubstitutions if v not in _d.substitutionSources]
    assert _typed == ["TEKTON_DASHBOARD_HOSTNAME"]
    assert _d.substitutionSources["GATEWAY_NAME"] == "gateway.name"
}

# Every one of the five is REQUIRED although the artifact defaults it, and each
# default names a DIFFERENT deployment. Live on u26-rke2-1, 2026-08-16: the
# store came up as `vault-homerun2-cd`, reading KV path `homerun2-cd`,
# authenticating as a ServiceAccount `eso` that the chart does not create — and
# reported nothing wrong until it tried to reach Vault.
#
# A store pointed at the wrong Vault LOOKS configured. That is the failure class
# requiredSubstitutions exists for: required, each value is either discovered
# from this cluster's own vaultIssuer or rejected at render time by name.
test_external_secrets_never_falls_back_to_another_clusters_mount = lambda {
    _c = {x.name: x for x in c.get("external-secrets").components}
    _req = _c["cluster-store-vault"].requiredSubstitutions
    _src = _c["cluster-store-vault"].substitutionSources
    _unguarded = [k for k, _ in _src if k not in _req]
    assert _unguarded == [], "a source with no required declaration falls back to the artifact default when it resolves to nothing"
}

# The two that are DECISIONS keep no source, and must not gain one: which Vault
# mount a cluster reads and what its store is called are choices, and a status
# field cannot make them. Only the mount path and role are facts the vaultIssuer
# produced.
test_external_secrets_sources_only_the_facts = lambda {
    _c = {x.name: x for x in c.get("external-secrets").components}
    _src = _c["cluster-store-vault"].substitutionSources
    assert sorted(_src) == ["VAULT_K8S_AUTH_MOUNT_PATH", "VAULT_K8S_AUTH_ROLE"]
    assert "VAULT_KV_PATH" not in _src, "which mount to read is a decision"
    assert "VAULT_CSS_NAME" not in _src, "what to call the store is a decision"
}
