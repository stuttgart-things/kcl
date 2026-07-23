# main.k
#
# Renders a Tekton PipelineRun for the stage-time `execute-tofu` pipeline,
# optionally wrapped in a kubernetes.m.crossplane.io Object so provider-kubernetes
# applies it on a target cluster. The tofu counterpart of kcl-tekton-pr (which
# does the same for the execute-ansible pipelines).
#
# Vault auth is AppRole: the execute-tofu task exchanges role_id/secret_id for a
# short-lived policy token per run, so nothing static and privileged is stored.
# role_id/secret_id arrive as TF_VAR_* from the credentials Secret; VAULT_ADDR
# from the vault Secret.
#
# Modes:
#   - Composition (function-kcl): params.oxr.spec drives it, returns items[].
#   - Flat (-D options / direct params): returns a single resource.
import tekton_pipelines.v1 as tekton
import .defaults
import .logic
import datetime
import crypto

# --- Read parameters (supports both Composition format and flat format) ---
_params = option("params") or {}
_spec = _params?.oxr?.spec or {}
_flat_params = _spec if _spec else _params

# --- Crossplane EnvironmentConfig context ---
# function-environment-configs merges the selected EnvironmentConfig(s) data
# under this well-known key. Precedence: explicit XR spec > EnvironmentConfig >
# flat -D option > hardcoded default.
_env = _params?.ctx?["apiextensions.crossplane.io/environment"] or {}

# --- Storage / identity ---
_storageSize = _flat_params?.storageSize or option("storageSize") or "500Mi"
_storageAccessModes = _flat_params?.storageAccessModes or option("storageAccessModes") or "ReadWriteOnce"
_storageClass = _flat_params?.storageClass or _env?.storageClass or option("storageClass") or "openebs-hostpath"
_namespace = _flat_params?.namespace or _env?.namespace or option("namespace") or "tekton-ci"
_pipelineRunName = _flat_params?.pipelineRunName or option("pipelineRunName") or None

# --- CONTENT source: the repo/revision that holds the OpenTofu configuration
# (what fetch-repository clones). ---
_gitRepoUrl = _flat_params?.gitRepoUrl or _env?.gitRepoUrl or option("gitRepoUrl") or "https://github.com/stuttgart-things/stage-time.git"
_gitRevision = _flat_params?.gitRevision or _env?.gitRevision or option("gitRevision") or "main"
_gitWorkspaceSubdirectory = _flat_params?.gitWorkspaceSubdirectory or option("gitWorkspaceSubdirectory") or ""

# --- Pipeline DEFINITION source for the PipelineRun's pipelineRef git resolver.
# Where the execute-tofu Pipeline YAML lives. Pinned to a stage-time release TAG
# for reproducibility; kept separate from the content source above so pointing
# gitRepoUrl at an external tofu repo does not drag the pipeline definition. ---
_pipelineRepoUrl = _flat_params?.pipelineRepoUrl or _env?.pipelineRepoUrl or option("pipelineRepoUrl") or "https://github.com/stuttgart-things/stage-time.git"
_pipelineRevision = _flat_params?.pipelineRevision or _env?.pipelineRevision or option("pipelineRevision") or "main"
_gitPath = _flat_params?.gitPath or _env?.gitPath or option("gitPath") or "pipelines/execute-tofu.yaml"

# --- Tofu run parameters ---
_tofuAction = _flat_params?.tofuAction or option("tofuAction") or "plan"
_subDirectory = _flat_params?.subDirectory or option("subDirectory") or ""
_autoApprove = str(_flat_params?.autoApprove or option("autoApprove") or "true")
_tfVars = _flat_params?.tfVars or option("tfVars") or []
_tfVarsFile = _flat_params?.tfVarsFile or option("tfVarsFile") or ""
_backendConfig = _flat_params?.backendConfig or option("backendConfig") or []
_initExtraArgs = _flat_params?.initExtraArgs or option("initExtraArgs") or ""
_planExtraArgs = _flat_params?.planExtraArgs or option("planExtraArgs") or ""
_tofuLog = _flat_params?.tofuLog or option("tofuLog") or ""
_tofuWorkingImage = _flat_params?.tofuWorkingImage or _env?.tofuWorkingImage or option("tofuWorkingImage") or "ghcr.io/opentofu/opentofu:1.9.0"
_userHome = _flat_params?.userHome or option("userHome") or "/home/nonroot"

# --- Credentials ---
# vaultSecretName holds VAULT_ADDR (+ optional VAULT_ROLE_ID/SECRET_ID/NAMESPACE).
# credentialsSecretName is injected wholesale as env (envFrom); put
# TF_VAR_vault_role_id / TF_VAR_vault_secret_id there for AppRole auth.
_vaultSecretName = _flat_params?.vaultSecretName or option("vaultSecretName") or "vault"
_credentialsSecretName = _flat_params?.credentialsSecretName or _env?.credentialsSecretName or option("credentialsSecretName") or "terraform-credentials"

# --- Input validation ---
assert logic.allowedImage(_tofuWorkingImage), "tofuWorkingImage must be from ghcr.io, docker.io, or quay.io"
assert _gitRepoUrl.startswith("https://github.com/"), "gitRepoUrl must be a valid GitHub HTTPS URL"
assert _pipelineRepoUrl.startswith("https://github.com/"), "pipelineRepoUrl must be a valid GitHub HTTPS URL"
assert len(_gitRevision) > 0, "gitRevision cannot be empty"
assert len(_pipelineRevision) > 0, "pipelineRevision cannot be empty"
assert logic.validAction(_tofuAction), "tofuAction must be plan, apply or destroy"
assert _storageSize.endswith("Mi") or _storageSize.endswith("Gi"), "storageSize must end with 'Mi' or 'Gi'"
assert _storageAccessModes in ["ReadWriteOnce", "ReadWriteMany", "ReadOnlyMany"], "storageAccessModes must be ReadWriteOnce, ReadWriteMany, or ReadOnlyMany"

# --- Crossplane wrapper settings ---
_wrapInCrossplane = _flat_params?.wrapInCrossplane or option("wrapInCrossplane") or False

# Object name derived from pipelineRunName (not a fixed literal): the Object name
# must be unique per XR, or two TofuRuns in one namespace compose the same Object
# and the second never syncs. Same reasoning as kcl-tekton-pr.
_defaultObjectName = _pipelineRunName if _pipelineRunName else "tekton-pipeline-run"
_crossplaneObjectName = _flat_params?.crossplaneObjectName or option("crossplaneObjectName") or _defaultObjectName
_crossplaneNamespace = _flat_params?.crossplaneNamespace or option("crossplaneNamespace") or "default"
_crossplaneProviderConfig = _flat_params?.crossplaneProviderConfig or option("crossplaneProviderConfig") or "kubernetes-provider"
_crossplaneTimeout = _flat_params?.crossplaneTimeout or option("crossplaneTimeout") or "60"

# Opt-in: when true the wrapped Object only reports Ready once the PipelineRun's
# "Succeeded" condition is True (provider-kubernetes DeriveFromCelQuery).
_deriveReadiness = _flat_params?.deriveReadiness or option("deriveReadiness") or False

# --- Timestamp / suffix for the fallback PipelineRun name ---
_timestamp = str(datetime.now())
_suffix = crypto.md5(_timestamp)[:8:]

# --- pipelineRef git resolver (pipeline DEFINITION) ---
_git_config_override = logic.pipelineRefParams(_pipelineRepoUrl, _pipelineRevision, _gitPath)

# --- workspace PVC ---
_workspace_config_override = {
    name = "shared-workspace"
    volumeClaimTemplate = {
        spec = {
            accessModes = [_storageAccessModes]
            resources = {
                requests = {
                    storage = _storageSize
                }
            }
            storageClassName = _storageClass
        }
    }
}

# --- pipeline params (execute-tofu) ---
_pipeline_params_override = {
    gitRepoUrl = _gitRepoUrl
    gitRevision = _gitRevision
    gitWorkspaceSubdirectory = _gitWorkspaceSubdirectory
    tofuAction = _tofuAction
    subDirectory = _subDirectory
    autoApprove = _autoApprove
    tfVars = _tfVars
    tfVarsFile = _tfVarsFile
    backendConfig = _backendConfig
    initExtraArgs = _initExtraArgs
    planExtraArgs = _planExtraArgs
    tofuLog = _tofuLog
    tofuWorkingImage = _tofuWorkingImage
    userHome = _userHome
    vaultSecretName = _vaultSecretName
    credentialsSecretName = _credentialsSecretName
}

# --- PipelineRun ---
_pipelineRun = tekton.PipelineRun {
    metadata = {
        name = _pipelineRunName or "run-tofu-${_suffix}"
        namespace = _namespace
    }
    spec = {
        pipelineRef = {
            resolver = "git"
            params = [{name = k, value = v} for k, v in _git_config_override]
        }
        params = [{name = k, value = v} for k, v in _pipeline_params_override]
        taskRunTemplate = defaults._task_run_template
        timeouts = defaults._timeouts
        workspaces = [_workspace_config_override]
    }
}

# --- Crossplane Object wrapper ---
_crossplaneObject = {
    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
    kind = "Object"
    metadata = {
        name = _crossplaneObjectName
        namespace = _crossplaneNamespace
        annotations = {
            "uptest.upbound.io/timeout" = _crossplaneTimeout
        }
    }
    spec = {
        # Update excluded: a PipelineRun is one-shot and Tekton rejects spec
        # updates once it completes; claiming Update makes provider-kubernetes'
        # observe dry-run SSA get denied and strands the Object. Delete included:
        # without it the PipelineRun outlives the XR with no owner reference.
        # Same hard-won policy set as kcl-tekton-pr (issue #75).
        managementPolicies = ["Observe", "Create", "Delete"]
        forProvider = {
            manifest = _pipelineRun
        }
        providerConfigRef = {
            kind = "ClusterProviderConfig"
            name = _crossplaneProviderConfig
        }
        if _deriveReadiness:
            readiness = {
                policy = "DeriveFromCelQuery"
                celQuery = "has(object.status) && has(object.status.conditions) && object.status.conditions.exists(c, c.type == \"Succeeded\" && c.status == \"True\")"
            }
    }
}

# --- Output ---
# Composition (nested) mode returns an items array; flat/direct mode returns a
# single resource.
if _spec:
    items = [
        if _wrapInCrossplane:
            _crossplaneObject
        else:
            _pipelineRun
    ]
elif _wrapInCrossplane:
    _crossplaneObject
else:
    _pipelineRun
