# Unit tests for kcl-tofu-pr logic. Run with `kcl test`. No cluster, no Crossplane.
import .logic as l

test_valid_actions = lambda {
    assert l.validAction("plan")
    assert l.validAction("apply")
    assert l.validAction("destroy")
    assert not l.validAction("frobnicate")
    assert not l.validAction("")
}

test_allowed_images = lambda {
    assert l.allowedImage("ghcr.io/opentofu/opentofu:1.9.0")
    assert l.allowedImage("docker.io/hashicorp/terraform:1.9")
    assert l.allowedImage("quay.io/x/y:z")
    assert not l.allowedImage("gitlab.com/x/y:z")
    assert not l.allowedImage("opentofu/opentofu:1.9.0")
}

test_pipeline_ref_params = lambda {
    p = l.pipelineRefParams("https://github.com/stuttgart-things/stage-time.git", "main", "pipelines/execute-tofu.yaml")
    assert p.url == "https://github.com/stuttgart-things/stage-time.git"
    assert p.revision == "main"
    assert p.pathInRepo == "pipelines/execute-tofu.yaml"
}

# The execute-tofu pipeline declares exactly these params; guard against a key
# being dropped from the renderer (which would fail only on a live run).
test_param_keys_cover_pipeline = lambda {
    _required = ["tofuAction", "subDirectory", "vaultSecretName", "credentialsSecretName", "backendConfig", "tfVars"]
    assert all k in _required {k in l.tofuParamKeys}, "every required key must be in tofuParamKeys"
    assert len(l.tofuParamKeys) == 16
}
