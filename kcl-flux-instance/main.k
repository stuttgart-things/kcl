# Default configuration values with ability to override via options
config = {
    # Basic metadata
    name = option("name") or "flux"
    namespace = option("namespace") or "flux-system"
    # Annotations
    reconcileEvery = option("reconcileEvery") or "1h"
    reconcileTimeout = option("reconcileTimeout") or "5m"
    # Distribution settings
    version = option("version") or "2.4"
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
    # Performance settings
    concurrent = int(option("concurrent")) if option("concurrent") else 10
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
      name: ${config.sopsSecretName}"""
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
  value: --concurrent=${config.concurrent}
- op: add
  path: /spec/template/spec/containers/0/args/-
  value: --requeue-dependency=${config.requeueDependency}"""
}

# Combine patches conditionally
_patches = [_sopsPatch] if config.sopsEnabled else []
_patches += [_perfPatch]

# Create optional Kubernetes Secrets
gitSecret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = config.gitPullSecret
        namespace = config.namespace
    }
    type = "Opaque"
    stringData = {
        username = config.gitUsername
        password = config.gitPassword
    }
}

sopsSecret = {
    apiVersion = "v1"
    kind = "Secret"
    metadata = {
        name = config.sopsSecretName
        namespace = config.namespace
    }
    type = "Opaque"
    stringData = {
        "age.agekey" = config.sopsAgeKey
    }
}

# Create the FluxInstance Custom Resource
fluxInstance = {
    apiVersion = "fluxcd.controlplane.io/v1"
    kind = "FluxInstance"
    metadata = {
        name = config.name
        namespace = config.namespace
        annotations = {
            "fluxcd.controlplane.io/reconcileEvery" = config.reconcileEvery
            "fluxcd.controlplane.io/reconcileTimeout" = config.reconcileTimeout
        }
    }
    spec = {
        distribution = {
            version = config.version
            registry = config.registry
            artifact = config.artifact
        }
        components = config.components
        cluster = {
            type = config.clusterType
            multitenant = config.multitenant
            networkPolicy = config.networkPolicy
            domain = config.domain
        }
        kustomize = {
            patches = _patches
        }
        sync = {
            kind = "GitRepository"
            url = config.gitUrl
            ref = config.gitRef
            path = config.gitPath
            pullSecret = config.gitPullSecret
        }
    }
}

# Build items array based on configuration
_items = [fluxInstance]

# Conditionally add secrets if renderSecrets is enabled and credentials are provided
_gitSecretItems = [gitSecret] if (config.renderSecrets and config.gitUsername and config.gitPassword) else []
_sopsSecretItems = [sopsSecret] if (config.renderSecrets and config.sopsEnabled and config.sopsAgeKey) else []

# Output
items = _items + _gitSecretItems + _sopsSecretItems
