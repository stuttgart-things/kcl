# schema.k
schema Destination:
    server?: str
    name?: str
    namespace: str

schema ResourceKind:
    group: str
    kind: str

schema ObjectMeta:
    name: str
    namespace: str
    labels?: {str: str}
    annotations?: {str: str}

schema AppProjectSpec:
    description?: str
    sourceRepos: [str]
    sourceNamespaces?: [str]
    destinations: [Destination]
    clusterResourceWhitelist?: [ResourceKind]
    clusterResourceBlacklist?: [ResourceKind]
    namespaceResourceWhitelist?: [ResourceKind]
    namespaceResourceBlacklist?: [ResourceKind]

schema AppProject:
    apiVersion: str = "argoproj.io/v1alpha1"
    kind: str = "AppProject"
    metadata: ObjectMeta
    spec: AppProjectSpec
