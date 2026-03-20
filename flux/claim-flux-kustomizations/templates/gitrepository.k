"""
Flux GitRepository Template

Generates a Flux GitRepository source resource for use by Kustomizations.

Usage:
    kcl run templates/gitrepository.k -D name=flux-infra -D url=https://github.com/stuttgart-things/flux.git
    kcl run templates/gitrepository.k -D name=flux-apps -D url=https://github.com/stuttgart-things/flux.git -D branch=main
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1.source_toolkit_fluxcd_io_v1_git_repository as source

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.ks?.spec or {}

# Common parameters
_name = _spec?.name or option("name") or "flux-infra"
_namespace = _spec?.namespace or option("namespace") or "flux-system"

# GitRepository-specific parameters
_url = _spec?.url or option("url") or "https://github.com/stuttgart-things/flux.git"
_interval = _spec?.interval or option("interval") or "1m0s"
_branch = _spec?.branch or option("branch") or "main"
_tag = _spec?.tag or option("tag") or ""
_semver = _spec?.semver or option("semver") or ""
_commit = _spec?.commit or option("commit") or ""
_timeout = _spec?.timeout or option("timeout") or "60s"
_suspend = _spec?.suspend or option("suspend") or False

# Authentication
_secretRefName = _spec?.secretRefName or option("secretRefName") or ""

# Common metadata
_commonLabelsStr = _spec?.commonLabels or option("commonLabels") or ""
_commonAnnotationsStr = _spec?.commonAnnotations or option("commonAnnotations") or ""

# Helper: parse comma-separated key=value pairs to dict
_parseKeyValuePairs = lambda s: str -> {str:str} {
    {kv.split("=")[0].strip(): kv.split("=")[1].strip() for kv in s.split(",") if kv and "=" in kv}
}

_commonLabels = _parseKeyValuePairs(_commonLabelsStr) if _commonLabelsStr else {}
_commonAnnotations = _parseKeyValuePairs(_commonAnnotationsStr) if _commonAnnotationsStr else {}

# GitRepository resource
source.GitRepository {
    metadata = v1.ObjectMeta {
        name = _name
        namespace = _namespace
        annotations = {
            "managed-by": "kcl-flux-kustomizations"
            "template": "gitrepository"
        } | _commonAnnotations
        labels = {
            "app.kubernetes.io/managed-by": "flux"
        } | _commonLabels
    }
    spec = source.SourceToolkitFluxcdIoV1GitRepositorySpec {
        url = _url
        interval = _interval
        timeout = _timeout

        if _suspend:
            suspend = _suspend

        ref = source.SourceToolkitFluxcdIoV1GitRepositorySpecRef {
            if _commit:
                commit = _commit
            elif _semver:
                semver = _semver
            elif _tag:
                tag = _tag
            else:
                branch = _branch
        }

        if _secretRefName:
            secretRef = source.SourceToolkitFluxcdIoV1GitRepositorySpecSecretRef {
                name = _secretRefName
            }
    }
}
