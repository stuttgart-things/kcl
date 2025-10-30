# main.k
import .schema  # Relative import for schema.k in the same directory

# Configuration variables (underscore prefix prevents them from being exported)
_nodeImage = option("nodeImage") or "kindest/node:v1.34.0"
_apiServerAddress = option("apiServerAddress") or "0.0.0.0"
_disableDefaultCNI = option("disableDefaultCNI") or True
_kubeProxyMode = option("kubeProxyMode") or "none"
_imageVolumeFeature = option("imageVolumeFeature") or True

# Dynamic port mappings configuration
_apiServerPort = option("apiServerPort") or 31643
_portRangeStart = option("portRangeStart") or 32443
_portRangeCount = option("portRangeCount") or 6

# Generate port mappings dynamically
_apiServerMapping = [{containerPort = 6443, hostPort = _apiServerPort, protocol = "TCP"}]
_portRangeMappings = [{containerPort = _portRangeStart + i, hostPort = _portRangeStart + i} for i in range(_portRangeCount)]
_extraPortMappings = option("extraPortMappings") or _apiServerMapping + _portRangeMappings

# Dynamic extra mounts configuration
_mountBasePath = option("mountBasePath") or "/mnt"
_clusterName = option("clusterName") or "platform-cluster"
_containerMountPath = option("containerMountPath") or "/data"

# Container registry mirror configuration
_registryMirror1 = option("registryMirror1") or "https://docker.harbor.idp.kubermatic.sva.dev"
_registryMirror2 = option("registryMirror2") or "https://registry-1.docker.io"

_cluster = schema.Cluster {
    name = _clusterName
    networking = {
        apiServerAddress = _apiServerAddress
        disableDefaultCNI = _disableDefaultCNI
        kubeProxyMode = _kubeProxyMode
    }
    featureGates = {
        "ImageVolume": _imageVolumeFeature
    }
    nodes = [
        {
            role = "control-plane"
            image = _nodeImage
            extraPortMappings = _extraPortMappings
        },
        {
            role = "worker"
            image = _nodeImage
            extraMounts = [{hostPath = "${_mountBasePath}/${_clusterName}1", containerPath = _containerMountPath}]
        },
        {
            role = "worker"
            image = _nodeImage
            extraMounts = [{hostPath = "${_mountBasePath}/${_clusterName}2", containerPath = _containerMountPath}]
        },
    ]
    containerdConfigPatches = [
        """[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = ["${_registryMirror1}", "${_registryMirror2}"]"""
    ]
}

# Output cluster fields at root level
kind = _cluster.kind
apiVersion = _cluster.apiVersion
name = _cluster.name
featureGates = _cluster.featureGates
networking = _cluster.networking
nodes = _cluster.nodes
containerdConfigPatches = _cluster.containerdConfigPatches
