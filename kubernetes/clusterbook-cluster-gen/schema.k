# schema.k
schema ObjectMeta:
    name: str
    namespace?: str
    labels?: {str:str}
    annotations?: {str:str}

schema SecretRef:
    # pragma: allowlist secret
    name: str
    # pragma: allowlist secret
    namespace: str
    # pragma: allowlist secret
    key?: str

schema ProviderConfigRef:
    name: str

schema LbRange:
    start: str
    stop: str

schema ClusterbookClusterSpec:
    # networkKey and providerConfigRef apply to default/classic clusters only;
    # for clusterType=kind, both are omitted and lbRange is required by the
    # operator instead.
    #
    # skipReservation generalises the kind case to ANY clusterType: the operator
    # (controller/reconciler.go) then makes no clusterbook call at all -- no IP,
    # no DNS, no GetClusterInfo, no release-on-delete -- and only writes the
    # ArgoCD cluster Secret with its labels. That is the shape a cluster needs
    # when something else already reserved its address: a Vcluster parent CR,
    # or a Flux-built cluster whose pipeline reserved through clusterbook
    # itself. Reserving a second time is not a duplicate, it is a NEW address
    # and a second wildcard record, with every step reporting success.
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
    labels?: {str:str}
    annotations?: {str:str}
    releaseOnDelete?: bool
    skipReservation?: bool

    check:
        # These mirror the CRD's own XValidation rules (api/v1alpha1/types.go in
        # clusterbook-operator). Keeping them here is what turns a bad
        # combination into a render error instead of a CR the API server
        # rejects after the pipeline already committed it.
        #
        # exactly one of kubeconfigSecretRef or existingSecretRef must be set
        (1 if kubeconfigSecretRef else 0) + (1 if existingSecretRef else 0) == 1, "exactly one of kubeconfigSecretRef or existingSecretRef must be set"
        # non-kind (default/classic/unset) clusters must carry both networkKey
        # and providerConfigRef -- unless they are registration-only
        clusterType == "kind" or skipReservation or (networkKey and providerConfigRef), "default/classic clusterType requires networkKey and providerConfigRef unless skipReservation is set"
        # kind clusters must not carry networkKey or providerConfigRef
        not (clusterType == "kind" and networkKey), "clusterType=kind must not set networkKey"
        not (clusterType == "kind" and providerConfigRef), "clusterType=kind must not set providerConfigRef"
        # Neither must a registration-only cluster. The operator does not
        # consult them, so emitting one is a claim the CR does not honour --
        # and a networkKey present without providerConfigRef is rejected by the
        # CRD's third rule regardless.
        not (skipReservation and networkKey), "skipReservation must not set networkKey -- nothing reserves from it"
        not (skipReservation and providerConfigRef), "skipReservation must not set providerConfigRef -- no clusterbook call is made"
        # CRD rule 4: with no reservation there is no IP or FQDN to build
        # data.server from, so it has to come from the kubeconfig.
        networkKey or preserveKubeconfigServer, "preserveKubeconfigServer must be true when no networkKey is reserved -- data.server has nowhere else to come from"

schema ClusterbookCluster:
    apiVersion: str = "clusterbook.stuttgart-things.com/v1alpha1"
    kind: str = "ClusterbookCluster"
    metadata: ObjectMeta
    spec: ClusterbookClusterSpec

