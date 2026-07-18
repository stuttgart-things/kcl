import ..schema as s

# dapr — https://github.com/stuttgart-things/flux/tree/main/apps/dapr
#
# Verified on kind1 2026-07-18: control-plane installs the dapr Helm chart
# (operator, placement, scheduler, sentry, sidecar-injector) from the v1.18.1
# artifact via flux-init source + flux-apps Kustomization.
#
# template-execution additionally requires a Secret providing GITHUB_TOKEN,
# BACKSTAGE_AUTH_TOKEN and REDIS_PASSWORD in the Kustomization's namespace,
# resolved via substituteFrom. Deliver it with sops-secrets-operator
# (InlineSopsSecret) BEFORE this component reconciles — substituteFrom resolves
# at build time, so a Secret applied by the same Kustomization is too late.
dapr: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/apps/dapr"
    defaultVersion = "v1.18.1"
    components = [
        {
            name = "control-plane"
            path = "./components/control-plane"
            wrapsHelmRelease = True
            timeout = "15m"
        }
        {
            name = "template-execution"
            path = "./components/template-execution"
            dependsOn = ["control-plane"]
        }
    ]
}
