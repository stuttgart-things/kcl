# schema.k
schema PortMapping:
    containerPort: int
    hostPort: int
    protocol?: str

schema ExtraMount:
    hostPath: str
    containerPath: str

schema Node:
    role: str
    image: str
    extraPortMappings?: [PortMapping]
    extraMounts?: [ExtraMount]

schema Networking:
    apiServerAddress: str
    disableDefaultCNI: bool
    kubeProxyMode: str

schema Cluster:
    kind: str = "Cluster"
    apiVersion: str = "kind.x-k8s.io/v1alpha4"
    name: str
    featureGates?: {str: bool}
    networking?: Networking
    nodes?: [Node]
    containerdConfigPatches?: [str]
