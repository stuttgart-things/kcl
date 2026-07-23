# Pure, testable helpers for kcl-tofu-pr. main.k does the option/env/spec
# resolution and calls these to build the pieces a caller depends on, so the
# invariants can be unit-tested without a cluster (see logic_test.k).

# The exact set of parameters the stage-time execute-tofu Pipeline declares.
# Kept here as the single source of truth so a test can assert the rendered
# PipelineRun passes every one — a missing key surfaces only as a Tekton
# "missing parameter" error on a live run otherwise.
tofuParamKeys: [str] = [
    "gitRepoUrl"
    "gitRevision"
    "gitWorkspaceSubdirectory"
    "tofuAction"
    "subDirectory"
    "autoApprove"
    "tfVars"
    "tfVarsFile"
    "backendConfig"
    "initExtraArgs"
    "planExtraArgs"
    "tofuLog"
    "tofuWorkingImage"
    "userHome"
    "vaultSecretName"
    "credentialsSecretName"
]

# Build the pipelineRef git-resolver params (pipeline DEFINITION source).
pipelineRefParams = lambda url: str, revision: str, path: str -> {str:str} {
    {
        url = url
        revision = revision
        pathInRepo = path
    }
}

# True when the action is one Tekton/execute-tofu accepts.
validAction = lambda action: str -> bool {
    action in ["plan", "apply", "destroy"]
}

# True when an image comes from an allowed registry.
allowedImage = lambda image: str -> bool {
    image.startswith("ghcr.io/") or image.startswith("docker.io/") or image.startswith("quay.io/")
}
