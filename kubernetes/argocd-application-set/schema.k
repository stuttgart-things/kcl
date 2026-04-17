# schema.k
schema ObjectMeta:
    name: str
    namespace: str
    labels?: {str: str}
    annotations?: {str: str}
    finalizers?: [str]

# ApplicationSet spec uses flexible nested dicts because generators and
# templates have dozens of shapes (git, list, cluster, matrix, merge,
# pullRequest, clusters, clusterDecisionResource, scmProvider, plugin, …).
# Top-level fields stay typed; nested content is passed through as-is.
schema ApplicationSetSpec:
    goTemplate?: bool
    goTemplateOptions?: [str]
    generators: [{str:}]
    template: {str:}
    syncPolicy?: {str:}
    strategy?: {str:}
    preservedFields?: {str:}
    templatePatch?: str

schema ApplicationSet:
    apiVersion: str = "argoproj.io/v1alpha1"
    kind: str = "ApplicationSet"
    metadata: ObjectMeta
    spec: ApplicationSetSpec
