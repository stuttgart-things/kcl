# kcl-tofu-pr

Renders a Tekton `PipelineRun` for the stage-time [`execute-tofu`](https://github.com/stuttgart-things/stage-time/blob/main/pipelines/execute-tofu.yaml) pipeline, optionally wrapped in a `kubernetes.m.crossplane.io/v1alpha1` `Object` so `provider-kubernetes` applies it on a target cluster.

The tofu counterpart of `kcl-tekton-pr` (which does the same for the execute-ansible pipelines). Same shape — git-resolver `pipelineRef`, workspace PVC, Object wrapper with the hard-won `managementPolicies = [Observe, Create, Delete]` — with the pipeline params swapped for tofu.

## Vault auth

The `execute-tofu` pipeline authenticates to Vault via **AppRole**: `role_id`/`secret_id` are long-lived login material, exchanged per run for a short-lived policy token, so nothing static and privileged is stored. They arrive as `TF_VAR_vault_role_id` / `TF_VAR_vault_secret_id` from `credentialsSecretName` (injected wholesale as env); `VAULT_ADDR` comes from `vaultSecretName`.

## Modes

- **Composition** (`function-kcl`): `params.oxr.spec` drives it; returns an `items` array.
- **Flat** (`-D` options / direct params): returns a single resource.

```bash
# raw PipelineRun
kcl run -D pipelineRunName=run-tofu -D subDirectory=tf -D tofuAction=apply

# wrapped Object for provider-kubernetes on a target cluster
kcl run -D pipelineRunName=run-tofu -D wrapInCrossplane=true \
  -D crossplaneProviderConfig=kind-test1-kubernetes -D deriveReadiness=true
```

## Key parameters

| Param | Default | Purpose |
|---|---|---|
| `pipelineRunName` | — | PipelineRun + Object name (unique per XR) |
| `gitRepoUrl` / `gitRevision` | stage-time / main | repo holding the tofu config (cloned) |
| `gitWorkspaceSubdirectory` | `""` | where the repo is cloned on the workspace |
| `subDirectory` | `""` | workspace subdir holding the tofu config |
| `tofuAction` | `plan` | plan / apply / destroy |
| `tfVars` / `backendConfig` | `[]` | `key+-value` pairs |
| `vaultSecretName` | `vault` | Secret with `VAULT_ADDR` |
| `credentialsSecretName` | `terraform-credentials` | Secret with `TF_VAR_*` (AppRole) |
| `pipelineRevision` | `main` | stage-time tag/rev for the pipeline definition |
| `wrapInCrossplane` | `false` | wrap in a provider-kubernetes Object |
| `deriveReadiness` | `false` | Object Ready only when PipelineRun Succeeded |

## Tests

`kcl test .` — validates the pure helpers in `logic.k` (action/image validation, the pipeline-ref params, and that the renderer covers every `execute-tofu` pipeline parameter).
