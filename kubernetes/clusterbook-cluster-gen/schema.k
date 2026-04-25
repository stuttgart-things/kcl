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

schema ClusterbookClusterSpec:
    networkKey: str
    clusterName: str
    providerConfigRef: ProviderConfigRef
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

schema ClusterbookCluster:
    apiVersion: str = "clusterbook.stuttgart-things.com/v1alpha1"
    kind: str = "ClusterbookCluster"
    metadata: ObjectMeta
    spec: ClusterbookClusterSpec
