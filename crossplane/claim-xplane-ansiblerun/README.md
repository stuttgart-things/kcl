# CLAIM-XPLANE-ANSIBLERUN

KCL schema for running Ansible playbooks via Crossplane and Tekton.

## Overview

This module provides a type-safe KCL interface for creating AnsibleRun claims that provision:
- Tekton PipelineRuns for Ansible playbook execution
- Crossplane-managed Kubernetes objects
- Ansible inventory and credential configuration

## ClaimTemplate

| Template | File | User gets prompted for | Use case |
|----------|------|----------------------|----------|
| **Simple Run** | `ansiblerun-simple.yaml` | Name, playbooks, hosts, credentials secret, provider config | Quick Ansible execution |

### Simple Run

Five questions: **run name**, **playbooks** (comma-separated), **target hosts** (comma-separated IPs), **credentials secret name**, and **Crossplane provider config**. Everything else uses sensible defaults with `hidden: true`.

Playbooks and hosts are entered as comma-separated strings since the ClaimTemplate schema doesn't support array/multiselect types. They get split into proper arrays in KCL.

## Usage

### Default (baseos setup on single host)

```bash
kcl run main.k
```

### Custom playbook and hosts

```bash
kcl run main.k \
  -D name=run-baseos-prod \
  -D playbooks="sthings.baseos.setup" \
  -D hosts="10.100.136.150,10.100.136.151" \
  -D ansibleCredentialsSecretName=ansible-credentials \
  -D crossplaneProviderConfig=dev
```

### Multiple playbooks

```bash
kcl run main.k \
  -D name=run-multi \
  -D playbooks="sthings.baseos.setup,sthings.baseos.network" \
  -D hosts="10.100.136.150"
```

### Using OCI Registry

```bash
kcl run oci://ghcr.io/stuttgart-things/claim-xplane-ansiblerun --tag 0.1.0 \
  -D name=run-baseos \
  -D playbooks="sthings.baseos.setup" \
  -D hosts="10.100.136.150"
```

## Available Parameters

### Visible (Simple Run)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Run name | `run-ansible` |
| `playbooks` | Playbooks (comma-separated) | `sthings.baseos.setup` |
| `hosts` | Target host IPs (comma-separated) | `10.100.136.150` |
| `ansibleCredentialsSecretName` | Credentials secret name | `ansible-credentials` |
| `crossplaneProviderConfig` | Crossplane provider config | `dev` |

### Hidden (defaults)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hostGroup` | Ansible host group | `all` |
| `namespace` | Claim namespace | `default` |
| `pipelineNamespace` | Tekton pipeline namespace | `tekton-ci` |
| `gitRepoUrl` | Pipeline git repo | `https://github.com/stuttgart-things/stage-time.git` |
| `gitRevision` | Git branch | `main` |
| `gitPath` | Pipeline file path | `pipelines/execute-ansible-playbooks.yaml` |
| `crossplaneNamespace` | Crossplane namespace | `default` |
| `ansibleVarsFile` | Ansible vars (comma-separated, overrides defaults) | baseos defaults |

## Requirements

- KCL v0.11.2+
- Crossplane with AnsibleRun XRD installed
- Tekton Pipelines configured
- Ansible credentials secret in cluster
