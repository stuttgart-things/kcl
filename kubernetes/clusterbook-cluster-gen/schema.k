# schema.k
schema ObjectMeta:
    name: str
    namespace?: str
    labels?: {str: str}
    annotations?: {str: str}

schema SecretRef:
    name: str  # pragma: allowlist secret
    namespace: str  # pragma: allowlist secret
    key?: str  # pragma: allowlist secret

schema ProviderConfigRef:
    name: str

schema LbRange:
    start: str
    stop: str

schema ClusterbookClusterSpec:
    # networkKey and providerConfigRef apply to default/classic clusters only;
    # for clusterType=kind, both are omitted and lbRange is required by the
    # operator instead.
    networkKey?: str
    clusterName: str
    providerConfigRef?: ProviderConfigRef
    clusterType?: str
    lbRange?: LbRange
    argocdNamespace?: str
    createDNS?: bool
    preserveKubeconfigServer?: bool
    useFQDNAsServer?: bool
    serverSubdomain?: str
    serverPort?: int
    kubeconfigSecretRef?: SecretRef
    existingSecretRef?: SecretRef
    labels?: {str: str}
    releaseOnDelete?: bool

    check:
        # exactly one of kubeconfigSecretRef or existingSecretRef must be set
        (1 if kubeconfigSecretRef else 0) + (1 if existingSecretRef else 0) == 1, \
            "exactly one of kubeconfigSecretRef or existingSecretRef must be set"
        # non-kind (default/classic/unset) clusters must carry both networkKey and providerConfigRef
        clusterType == "kind" or (networkKey and providerConfigRef), \
            "default/classic clusterType requires networkKey and providerConfigRef"
        # kind clusters must not carry networkKey or providerConfigRef
        not (clusterType == "kind" and networkKey), \
            "clusterType=kind must not set networkKey"
        not (clusterType == "kind" and providerConfigRef), \
            "clusterType=kind must not set providerConfigRef"

schema ClusterbookCluster:
    apiVersion: str = "clusterbook.stuttgart-things.com/v1alpha1"
    kind: str = "ClusterbookCluster"
    metadata: ObjectMeta
    spec: ClusterbookClusterSpec
