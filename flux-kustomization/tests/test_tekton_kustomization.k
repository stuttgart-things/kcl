"""
Test: Tekton Kustomization with variable substitution from params (YAML)
"""

# Build a plain mapping (no CRD model imports) so the test runs regardless of cwd
p = option("params") or {}
spec = p?.oxr?.spec or p?.spec or p or {}

resource = {
	apiVersion = "kustomize.toolkit.fluxcd.io/v1"
	kind = "Kustomization"
	metadata = {
		name = spec?.name or "tekton"
		namespace = spec?.namespace or "flux-system"
		labels = {}
		annotations = {
			"krm.kcl.dev/composition-resource-name" = "flux-kustomization-{}".format(spec?.name or "tekton")
		}
	}
	spec = {
		interval = spec?.interval or "1h"
		retryInterval = spec?.retryInterval or "1m"
		timeout = spec?.timeout or "5m"
		path = spec?.path or "./cicd/tekton"
		prune = True if spec?.prune == None else spec?.prune
		wait = True if spec?.wait == None else spec?.wait
		sourceRef = {
			kind = spec?.sourceKind or "GitRepository"
			name = spec?.sourceName or "flux-apps"
		}
		postBuild = {
			substitute = spec?.postBuild?.substitute or {}
		} if spec?.postBuild else {}
	}
}

items = [resource]
