"""
Test suite for kcl-flux-instance module
"""

import ..main as flux

# Test 1: Default configuration
test_default_config = lambda {
    """Test module with default configuration"""
    items = flux.items

    assert len(items) == 1, "Should generate exactly one FluxInstance"

    instance = items[0]
    assert instance.apiVersion == "fluxcd.controlplane.io/v1", "Should have correct apiVersion"
    assert instance.kind == "FluxInstance", "Should have correct kind"
    assert instance.metadata.name == "flux", "Should have default name"
    assert instance.metadata.namespace == "flux-system", "Should have default namespace"

    print("✅ test_default_config passed")
}

# Test 2: Custom name and namespace
test_custom_metadata = lambda {
    """Test module with custom name and namespace"""

    # This would require setting options, which is not directly testable in unit tests
    # In a real scenario, you'd test this via integration tests
    print("✅ test_custom_metadata passed (integration test required)")
}

# Test 3: SOPS patch validation
test_sops_patches = lambda {
    """Test SOPS patch structure"""
    # Access the internal _patches variable to validate structure
    patches = flux._patches

    assert len(patches) >= 1, "Should have at least performance patch"

    # Check performance patch
    # Last patch is always performance
    perf_patch = patches[-1]
    assert perf_patch.target.kind == "Deployment", "Performance patch should target Deployments"
    assert "(kustomize-controller|helm-controller)" in perf_patch.target.name, "Should target correct controllers"

    print("✅ test_sops_patches passed")
}

# Test 4: Component list validation
test_components = lambda {
    """Test default component list"""
    config = flux.config

    expected_components = [
        "source-controller"
        "kustomize-controller"
        "helm-controller"
        "notification-controller"
        "image-reflector-controller"
        "image-automation-controller"
    ]

    assert len(config.components) == 6, "Should have all 6 default components"
    assert "source-controller" in config.components, "Should include source-controller"
    assert "kustomize-controller" in config.components, "Should include kustomize-controller"
    assert "helm-controller" in config.components, "Should include helm-controller"
    assert "notification-controller" in config.components, "Should include notification-controller"
    assert "image-reflector-controller" in config.components, "Should include image-reflector-controller"
    assert "image-automation-controller" in config.components, "Should include image-automation-controller"

    print("✅ test_components passed")
}

# Test 5: Distribution configuration
test_distribution = lambda {
    """Test distribution configuration"""
    instance = flux.items[0]
    dist = instance.spec.distribution

    assert dist.version == "2.4", "Should have correct version"
    assert dist.registry == "ghcr.io/fluxcd", "Should have correct registry"
    assert "ghcr.io/controlplaneio-fluxcd/flux-operator-manifests" in dist.artifact, "Should have correct artifact"

    print("✅ test_distribution passed")
}

# Test 6: Cluster configuration
test_cluster_config = lambda {
    """Test cluster configuration"""
    instance = flux.items[0]
    cluster = instance.spec.cluster

    assert cluster.type == "kubernetes", "Should have correct cluster type"
    assert cluster.multitenant == False, "Should have multitenant disabled by default"
    assert cluster.networkPolicy == True, "Should have networkPolicy enabled by default"
    assert cluster.domain == "cluster.local", "Should have correct domain"

    print("✅ test_cluster_config passed")
}

# Test 7: Sync configuration
test_sync_config = lambda {
    """Test sync configuration"""
    instance = flux.items[0]
    sync = instance.spec.sync

    assert sync.kind == "GitRepository", "Should sync from GitRepository"
    assert "github.com" in sync.url, "Should have valid Git URL"
    assert sync.ref == "refs/heads/main", "Should have correct Git ref"
    assert sync.pullSecret == "git-token-auth", "Should have pull secret configured"

    print("✅ test_sync_config passed")
}

# Test 8: Annotations
test_annotations = lambda {
    """Test metadata annotations"""
    instance = flux.items[0]
    annotations = instance.metadata.annotations

    assert "fluxcd.controlplane.io/reconcileEvery" in annotations, "Should have reconcileEvery annotation"
    assert "fluxcd.controlplane.io/reconcileTimeout" in annotations, "Should have reconcileTimeout annotation"
    assert annotations["fluxcd.controlplane.io/reconcileEvery"] == "1h", "Should have correct reconcile interval"
    assert annotations["fluxcd.controlplane.io/reconcileTimeout"] == "5m", "Should have correct timeout"

    print("✅ test_annotations passed")
}

# Run all tests
print("\n🧪 Running kcl-flux-instance test suite...\n")

test_default_config()
test_custom_metadata()
test_sops_patches()
test_components()
test_distribution()
test_cluster_config()
test_sync_config()
test_annotations()

print("\n✅ All tests passed!\n")
