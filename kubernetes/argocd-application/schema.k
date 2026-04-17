# schema.k
schema ObjectMeta:
    name: str
    namespace: str
    labels?: {str: str}
    annotations?: {str: str}
    finalizers?: [str]

schema Destination:
    server?: str
    name?: str
    namespace: str

schema HelmParameter:
    name: str
    value: str
    forceString?: bool

schema SourceHelm:
    releaseName?: str
    valueFiles?: [str]
    values?: str
    parameters?: [HelmParameter]
    skipCrds?: bool
    passCredentials?: bool

schema Source:
    repoURL: str
    path?: str
    targetRevision?: str
    chart?: str
    helm?: SourceHelm
    kustomize?: {str:}
    directory?: {str:}
    plugin?: {str:}
    ref?: str

schema SyncAutomated:
    prune?: bool
    selfHeal?: bool
    allowEmpty?: bool

schema RetryBackoff:
    duration?: str
    factor?: int
    maxDuration?: str

schema SyncRetry:
    limit?: int
    backoff?: RetryBackoff

schema SyncPolicy:
    automated?: SyncAutomated
    syncOptions?: [str]
    retry?: SyncRetry

schema Info:
    name: str
    value: str

schema ApplicationSpec:
    project: str
    source?: Source
    sources?: [Source]
    destination: Destination
    syncPolicy?: SyncPolicy
    revisionHistoryLimit?: int
    info?: [Info]

schema Application:
    apiVersion: str = "argoproj.io/v1alpha1"
    kind: str = "Application"
    metadata: ObjectMeta
    spec: ApplicationSpec
