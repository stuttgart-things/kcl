"""
Simple example of PipelineIntegration resource usage.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_pipeline_integration as pipelinemod

# Simple Tekton Pipeline Integration
pipelinemod.PipelineIntegration {
    metadata = v1.ObjectMeta {
        name = "tekton-pipelines"
        namespace = "default"
    }

    spec = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpec {
        engine = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecEngine {
            type = "tekton"
        }
        targetCluster = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTargetCluster {
            name = "in-cluster"
            scope = "Cluster"
        }
        tekton = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTekton {
            namespace = "tekton-operator"
            pipelineNamespace = "tekton-pipelines"
            version = "0.77.5"
            enableTektonPipeline = True
            enableTektonTriggers = True
        }
    }
}
