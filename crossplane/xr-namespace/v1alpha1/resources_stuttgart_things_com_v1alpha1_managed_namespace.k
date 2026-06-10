"""
This file describes the ManagedNamespace XR (resources.stuttgart-things.com/v1alpha1).
It mirrors the CompositeResourceDefinition in
crossplane-configurations/k8s/namespace/apis/definition.yaml.
"""
import ..k8s.apimachinery.pkg.apis.meta.v1


schema ManagedNamespace:
    r"""
    resources stuttgart things com v1alpha1 managed namespace

    Attributes
    ----------
    apiVersion : str, default is "resources.stuttgart-things.com/v1alpha1", required
        APIVersion defines the versioned schema of this representation of an object.
    kind : str, default is "ManagedNamespace", required
        Kind is a string value representing the REST resource this object represents.
    metadata : v1.ObjectMeta, default is Undefined, optional
        metadata
    spec : ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpec, default is Undefined, required
        spec
    status : ResourcesStuttgartThingsComV1alpha1ManagedNamespaceStatus, default is Undefined, optional
        status
    """


    apiVersion: "resources.stuttgart-things.com/v1alpha1" = "resources.stuttgart-things.com/v1alpha1"

    kind: "ManagedNamespace" = "ManagedNamespace"

    metadata?: v1.ObjectMeta

    spec: ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpec

    status?: ResourcesStuttgartThingsComV1alpha1ManagedNamespaceStatus


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpec:
    r"""
    resources stuttgart things com v1alpha1 managed namespace spec

    Attributes
    ----------
    providerConfigRef : str, default is Undefined, required
        Name of the ClusterProviderConfig to use for the Kubernetes provider
    name : str, default is Undefined, required
        Name of the Namespace to create on the target cluster
    labels : {str:str}, default is Undefined, optional
        Labels applied to the Namespace
    annotations : {str:str}, default is Undefined, optional
        Annotations applied to the Namespace
    resourceQuota : ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecResourceQuota, default is Undefined, optional
        Optional ResourceQuota. Omit the block to skip.
    limitRange : ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecLimitRange, default is Undefined, optional
        Optional LimitRange. Omit the block to skip.
    networkPolicy : ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecNetworkPolicy, default is Undefined, optional
        Optional baseline NetworkPolicies.
    roleBindings : [ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0], default is Undefined, optional
        RoleBindings created in the Namespace.
    """


    providerConfigRef: str

    name: str

    labels?: {str:str}

    annotations?: {str:str}

    resourceQuota?: ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecResourceQuota

    limitRange?: ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecLimitRange

    networkPolicy?: ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecNetworkPolicy

    roleBindings?: [ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0]


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecResourceQuota:
    r"""
    Optional ResourceQuota.

    Attributes
    ----------
    hard : {str:str}, default is Undefined, required
        Quota keys (e.g. requests.cpu, limits.memory, pods) -> quantity strings
    """


    hard: {str:str}


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecLimitRange:
    r"""
    Optional LimitRange.

    Attributes
    ----------
    limits : [ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecLimitRangeLimitsItems0], default is Undefined, required
        Mirrors corev1 LimitRangeSpec.limits
    """


    limits: [ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecLimitRangeLimitsItems0]


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecLimitRangeLimitsItems0:
    r"""
    resources stuttgart things com v1alpha1 managed namespace spec limit range limits items0

    Attributes
    ----------
    type : str, default is Undefined, required
        Container, Pod, PersistentVolumeClaim, ...
    default : {str:str}, default is Undefined, optional
        default
    defaultRequest : {str:str}, default is Undefined, optional
        default request
    max : {str:str}, default is Undefined, optional
        max
    min : {str:str}, default is Undefined, optional
        min
    maxLimitRequestRatio : {str:str}, default is Undefined, optional
        max limit request ratio
    """


    type: str

    default?: {str:str}

    defaultRequest?: {str:str}

    max?: {str:str}

    min?: {str:str}

    maxLimitRequestRatio?: {str:str}


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecNetworkPolicy:
    r"""
    Optional baseline NetworkPolicies.

    Attributes
    ----------
    denyAll : bool, default is False, optional
        When true, render a default-deny NetworkPolicy (ingress + egress) selecting all pods.
    """


    denyAll?: bool = False


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0:
    r"""
    resources stuttgart things com v1alpha1 managed namespace spec role bindings items0

    Attributes
    ----------
    name : str, default is Undefined, required
        name
    roleRef : ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0RoleRef, default is Undefined, required
        role ref
    subjects : [ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0SubjectsItems0], default is Undefined, required
        subjects
    """


    name: str

    roleRef: ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0RoleRef

    subjects: [ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0SubjectsItems0]


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0RoleRef:
    r"""
    resources stuttgart things com v1alpha1 managed namespace spec role bindings items0 role ref

    Attributes
    ----------
    kind : str, default is "ClusterRole", optional
        ClusterRole or Role
    name : str, default is Undefined, required
        name
    apiGroup : str, default is "rbac.authorization.k8s.io", optional
        api group
    """


    kind?: str = "ClusterRole"

    name: str

    apiGroup?: str = "rbac.authorization.k8s.io"


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceSpecRoleBindingsItems0SubjectsItems0:
    r"""
    resources stuttgart things com v1alpha1 managed namespace spec role bindings items0 subjects items0

    Attributes
    ----------
    kind : str, default is Undefined, required
        User, Group or ServiceAccount
    name : str, default is Undefined, required
        name
    namespace : str, default is Undefined, optional
        Required for ServiceAccount subjects
    apiGroup : str, default is Undefined, optional
        rbac.authorization.k8s.io for User/Group; omit for ServiceAccount
    """


    kind: str

    name: str

    namespace?: str

    apiGroup?: str


schema ResourcesStuttgartThingsComV1alpha1ManagedNamespaceStatus:
    r"""
    resources stuttgart things com v1alpha1 managed namespace status

    Attributes
    ----------
    namespace : str, default is Undefined, optional
        namespace
    ready : bool, default is Undefined, optional
        ready
    """


    namespace?: str

    ready?: bool
