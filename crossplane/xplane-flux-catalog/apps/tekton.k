import ..schema as s

# tekton — https://github.com/stuttgart-things/flux/tree/main/cicd/tekton
#
# The reason a management cluster needs it at all: an `AnsibleRun` IS a Tekton
# PipelineRun. A cluster without Tekton can create a VM and then cannot finish
# it — the ClusterStack reaches `stage: vm` and stays there. Measured on
# u26-rke2-1, 2026-08-17, which had every Configuration healthy and no Tekton.
#
# The first entry from cicd/ rather than apps/ or infra/. Those were the only
# two directories the flux release workflow published, so none of cicd/ existed
# as an OCI artifact until stuttgart-things/flux#196 — which is why this entry
# could not be written earlier, not because nobody wanted it.
#
# FOUR components, not one, and that split is the whole point of the entry:
# only `dashboard` needs a value nobody can default. operator needs none at
# all, config and ci-namespace default everything. Bundled, every Tekton user
# would owe a domain whether or not they wanted a dashboard — and Flux
# substitutes an empty string rather than failing, so they would get a
# certificate-less route pointing at nothing.
tekton: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/cicd/tekton"
    defaultVersion = "v1.20.0"
    components = [
        s.Component {
            name = "install"
            # The artifact's root pulls components/operator and components/config
            # together: the operator, and the TektonConfig that decides which
            # sub-components it installs. Separating them would mean a running
            # operator with no configuration, which installs nothing.
            path = "./"
            # The operator brings its own CRDs and waits for them; 10m is not
            # enough on a cluster pulling the images for the first time.
            timeout = "15m"
        }
        s.Component {
            name = "ci-namespace"
            path = "./components/ci-namespace"
            # Upstream calls this opt-in. Here it is ON by default, deliberately:
            # every Tekton in this fleet exists to run Crossplane-managed
            # PipelineRuns, and the namespace carries
            # `operator.tekton.dev/prune.skip: "true"`. Without it the
            # cluster-wide pruner deletes those PipelineRuns overnight and
            # Crossplane recreates them each morning — which reads like runs
            # re-triggering themselves and is documented in the artifact's README
            # as exactly that confusion.
            #
            # No dependsOn: a namespace needs nothing the operator installs.
        }
        s.Component {
            name = "dashboard"
            path = "./components/dashboard-httproute"
            optional = True
            # Depends on install because the route targets the dashboard Service
            # the operator creates. Flux would apply the HTTPRoute regardless;
            # the dependency is what keeps it from being green while pointing at
            # nothing.
            dependsOn = ["install"]
            # HOSTNAME has no manifest default and is a decision — what a service
            # is CALLED is not a fact about the cluster. DOMAIN and GATEWAY_NAME
            # are facts, and the platform already publishes both.
            requiredSubstitutions = [
                "TEKTON_DASHBOARD_DOMAIN"
                "TEKTON_DASHBOARD_HOSTNAME"
                "GATEWAY_NAME"
            ]
            # GATEWAY_NAME carries a manifest default (`cilium-gateway`), so
            # requiring it is not about the artifact — it is this catalog's rule
            # that a source must belong to a declared variable, or a typo in the
            # path would resolve to nothing and stay invisible. The source always
            # resolves; the platform sets that name on the Gateway it creates.
            substitutionSources = {
                TEKTON_DASHBOARD_DOMAIN = "ipReservation.domain"
                GATEWAY_NAME = "gateway.name"
            }
        }
    ]
}
