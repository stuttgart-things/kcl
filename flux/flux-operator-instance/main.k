# Default configuration values with ability to override via options
_config = {
    # Basic metadata
    name = option("name") or "flux"
    namespace = option("namespace") or "flux-system"
    # Annotations
    reconcileEvery = option("reconcileEvery") or "1h"
    reconcileTimeout = option("reconcileTimeout") or "5m"
    # Distribution settings
    version = str(option("version")) if option("version") else "2.4"
    registry = option("registry") or "ghcr.io/fluxcd"
    artifact = option("artifact") or "oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests"
    # Components - can be overridden as a list
    components = option("components") or [
        "source-controller"
        "kustomize-controller"
        "helm-controller"
        "notification-controller"
        "image-reflector-controller"
        "image-automation-controller"
    ]
    # Cluster settings
    clusterType = option("clusterType") or "kubernetes"
    multitenant = True if option("multitenant") in ["true", True] else False
    networkPolicy = False if option("networkPolicy") in ["false", False] else True
    domain = option("domain") or "cluster.local"
    # SOPS settings
    sopsEnabled = True if option("sopsEnabled") == None else (option("sopsEnabled") == "true" or option("sopsEnabled") == True)
    sopsSecretName = option("sopsSecretName") or "sops-age"
    # Performance settings - safe string to int conversion
    _concurrentValue = option("concurrent")
    concurrent = int(str(_concurrentValue)) if _concurrentValue and str(_concurrentValue).isdigit() else 10
    requeueDependency = option("requeueDependency") or "5s"
    # Git sync settings
    gitUrl = option("gitUrl") or "https://github.com/stuttgart-things/stuttgart-things.git"
    gitRef = option("gitRef") or "refs/heads/main"
    gitPath = option("gitPath") or "clusters/vcluster/vso"
    gitPullSecret = option("gitPullSecret") or "git-token-auth"
    # Secret rendering options
    renderSecrets = True if option("renderSecrets") in ["true", True] else False
    gitUsername = option("gitUsername") or ""
    gitPassword = option("gitPassword") or ""
    sopsAgeKey = option("sopsAgeKey") or ""
}

# Build patches list based on configuration
_sopsPatch = {
    patch = """- op: add
  path: /spec/decryption
  value:
    provider: sops
    secretRef:
      name: ${_config.sopsSecretName}"""
    target = {
        group = "kustomize.toolkit.fluxcd.io"
        version = "v1"
        kind = "Kustomization"
    }
}

_perfPatch = {
    target = {
        kind = "Deployment"
        name = "(kustomize-controller|helm-controller)"
    }
    patch = """- op: add
  path: /spec/template/spec/containers/0/args/-
  value: --concurrent=${_config.concurrent}
- op: add
  path: /spec/template/spec/containers/0/args/-
  value: --requeue-dependency=${_config.requeueDependency}"""
}

# Combine patches conditionally
_patches = [_sopsPatch] if _config.sopsEnabled else []
_patches += [_perfPatch]

# Create optional Kubernetes Secrets
_gitSecret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = _config.gitPullSecret
        namespace = _config.namespace
    }
    type = "Opaque"
    stringData = {
        username = _config.gitUsername
        password = _config.gitPassword
    }
}

_sopsSecret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = _config.sopsSecretName
        namespace = _config.namespace
    }
    type = "Opaque"
    stringData = {
        "age.agekey" = _config.sopsAgeKey
    }
}

# Create the FluxInstance Custom Resource
_fluxInstance = {
    apiVersion = "fluxcd.controlplane.io/v1"
    kind = "FluxInstance"
    metadata = {
        name = _config.name
        namespace = _config.namespace
        annotations = {
            "fluxcd.controlplane.io/reconcileEvery" = _config.reconcileEvery
            "fluxcd.controlplane.io/reconcileTimeout" = _config.reconcileTimeout
        }
    }
    spec = {
        distribution = {
            version = _config.version
            registry = _config.registry
            artifact = _config.artifact
        }
        components = _config.components
        cluster = {
            type = _config.clusterType
            multitenant = _config.multitenant
            networkPolicy = _config.networkPolicy
            domain = _config.domain
        }
        kustomize = {
            patches = _patches
        }
        sync = {
            kind = "GitRepository"
            url = _config.gitUrl
            ref = _config.gitRef
            path = _config.gitPath
            pullSecret = _config.gitPullSecret
        }
    }
}

# Build items array based on configuration
_items = [_fluxInstance]

# Conditionally add secrets if renderSecrets is enabled and credentials are provided
_gitSecretItems = [_gitSecret] if (_config.renderSecrets and _config.gitUsername and _config.gitPassword) else []
_sopsSecretItems = [_sopsSecret] if (_config.renderSecrets and _config.sopsEnabled and _config.sopsAgeKey) else []

# Output - only this will be rendered
items = _items + _gitSecretItems + _sopsSecretItems
