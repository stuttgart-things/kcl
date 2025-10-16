import models.v1beta1.helm_crossplane_io_v1beta1_release as helm

release = helm.Release {
    apiVersion: "helm.crossplane.io/v1beta1"
    kind: "Release"
    metadata: {
        name: "my-helm-release"
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
            values: {
                replicaCount: 2
            }
        }
    }
}
