import models.v1beta1.helm_crossplane_io_v1beta1_release as helm
import models.v1beta1.helmm.helmm_crossplane_io_v1beta1_release as helmm

release = helm.Release {
    apiVersion: "helm.crossplane.io/v1beta1"
    kind: "Release"
    metadata: {
        name: "example-release"
    }
    spec: {
        providerConfigRef: { name: "default" }
        forProvider: {
            chart: {
                name: "nginx"
                repository: "https://charts.bitnami.com/bitnami"
                version: "15.0.0"
            }
            namespace: "default"
        }
    }
}

# Crossplane v2 namespaced managed Release (helm.m.crossplane.io/v1beta1)
namespaced_release = helmm.Release {
    apiVersion: "helm.m.crossplane.io/v1beta1"
    kind: "Release"
    metadata: {
        name: "example-release"
        namespace: "default"
    }
    spec: {
        providerConfigRef: {
            kind: "ClusterProviderConfig"
            name: "default"
        }
        forProvider: {
            chart: {
                name: "nginx"
                repository: "https://charts.bitnami.com/bitnami"
                version: "15.0.0"
            }
        }
    }
}
