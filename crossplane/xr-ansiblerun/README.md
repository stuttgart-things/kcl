# XR-ANSIBLERUN

KCL module for the `AnsibleRun` XR (`resources.stuttgart-things.com/v1alpha1`),
the Ansible-over-Tekton abstraction from the
[`ansible-run` Crossplane Configuration](../../../crossplane/crossplane-configurations/cicd/ansible-run).

An `AnsibleRun` renders a Tekton `PipelineRun` (wrapped in a
`kubernetes.m.crossplane.io` Object) that runs Ansible playbooks against a
target host. Shared defaults - working image, extra collections, git revision,
credentials Secret, namespace - are **not** set on the claim; they come from the
`EnvironmentConfig` selected by `environmentConfig`. Precedence is
**explicit XR value > EnvironmentConfig > KCL module default**, so thin claims
only pick the playbook(s), the target host(s) and the Crossplane wrap settings.

## Templates

| Template | Params | Purpose |
|---|---|---|
| `minimal`  | `pipelineRunName`, `namespace`, `gitRepoUrl`, `crossplaneProviderConfig` | XRD-required fields plus the wrap-Object inputs. |
| `baseos`   | + `hosts` | Proven preset - runs `sthings.baseos.setup` against `hosts`; image/collections/gitRevision fall through to the EnvironmentConfig. |
| `detailed` | every spec field | Full XRD surface: image, collections, storage, git revision, readiness. |

```bash
# minimal - a bare PipelineRun wrapper
kcl run oci://ghcr.io/stuttgart-things/xr-ansiblerun --tag 0.1.0 \
  -D templateName=minimal -D name=ansible-run -D pipelineRunName=run-ansible \
  -D namespace=tekton-ci -D crossplaneProviderConfig=in-cluster
```

```bash
# baseos - run sthings.baseos.setup against a single host (mirrors the proven XR)
kcl run oci://ghcr.io/stuttgart-things/xr-ansiblerun --tag 0.1.0 \
  -D templateName=baseos -D name=ansible-run-test \
  -D pipelineRunName=run-ansible-baseos -D namespace=tekton-ci \
  -D hosts=192.168.10.149 -D crossplaneProviderConfig=in-cluster \
  -D crossplaneObjectName=run-ansible-test
```

`hosts` accepts a single value or a comma-separated list (`-D hosts=10.0.0.1,10.0.0.2`)
and is rendered into the `ansibleVarsInventory` `all+[...]` group. Pass a fully
formed spec (including `ansibleVarsFile` / `ansibleVarsInventory`) via a params
data file when you need the exact lines from `ansiblerun-data.yaml`.
