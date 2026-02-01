"""
Example usage of PipelineIntegration resource from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_pipeline_integration as pipelinemod

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.resource?.spec or {}

# Template selector
_templateName = option("templateName") or _params?.templateName or "tekton-basic"  # Options: "tekton-basic", "tekton-full", "minimal"

# Common parameters
_name = option("name") or _params?.name or "tekton-pipelines"
_namespace = option("namespace") or _params?.namespace or "default"

# Target cluster parameters
_targetClusterSpec = _spec?.targetCluster or {}
_targetClusterName = _targetClusterSpec?.name or option("targetClusterName") or "in-cluster"
_targetClusterScope = _targetClusterSpec?.scope or option("targetClusterScope") or "Cluster"

# Engine parameters
_engineSpec = _spec?.engine or {}
_engineType = _engineSpec?.type or option("engineType") or "tekton"

# Tekton-specific parameters
_tektonSpec = _spec?.tekton or {}
_tektonNamespace = _tektonSpec?.namespace or option("tektonNamespace") or "tekton-operator"
_tektonPipelineNamespace = _tektonSpec?.pipelineNamespace or option("pipelineNamespace") or "tekton-pipelines"
_tektonVersion = _tektonSpec?.version or option("version") or "0.77.5"
_tektonAutoInstall = _tektonSpec?.autoInstallComponents if _tektonSpec?.autoInstallComponents != None else (option("autoInstallComponents") if option("autoInstallComponents") != None else False)
_tektonImagePullPolicy = _tektonSpec?.imagePullPolicy or option("imagePullPolicy") or "Always"
_tektonDisableInlineSpec = _tektonSpec?.disableInlineSpec or option("disableInlineSpec") or ""
_tektonEnablePipeline = _tektonSpec?.enableTektonPipeline if _tektonSpec?.enableTektonPipeline != None else (option("enableTektonPipeline") if option("enableTektonPipeline") != None else True)
_tektonEnableTriggers = _tektonSpec?.enableTektonTriggers if _tektonSpec?.enableTektonTriggers != None else (option("enableTektonTriggers") if option("enableTektonTriggers") != None else False)
_tektonEnableDashboard = _tektonSpec?.enableTektonDashboard if _tektonSpec?.enableTektonDashboard != None else (option("enableTektonDashboard") if option("enableTektonDashboard") != None else False)
_tektonEnablePruner = _tektonSpec?.enableTektonPruner if _tektonSpec?.enableTektonPruner != None else (option("enableTektonPruner") if option("enableTektonPruner") != None else False)
_tektonChartRepository = _tektonSpec?.chartRepository or option("chartRepository") or "oci://ghcr.io/stuttgart-things/tekton"

# Tekton Basic Template - Standard Tekton Pipeline setup
if _templateName == "tekton-basic":
    pipelinemod.PipelineIntegration {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "crossplane.io/managed-by": "kcl"
            }
        }

        spec = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpec {
            engine = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecEngine {
                type = _engineType
            }
            targetCluster = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTargetCluster {
                name = _targetClusterName
                scope = _targetClusterScope
            }
            tekton = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTekton {
                namespace = _tektonNamespace
                pipelineNamespace = _tektonPipelineNamespace
                version = _tektonVersion
                autoInstallComponents = _tektonAutoInstall
                enableTektonPipeline = _tektonEnablePipeline
                enableTektonTriggers = _tektonEnableTriggers
                enableTektonDashboard = _tektonEnableDashboard
                enableTektonPruner = _tektonEnablePruner
            }
        }
    }

# Tekton Full Template - All Tekton components enabled
if _templateName == "tekton-full":
    pipelinemod.PipelineIntegration {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
            annotations = {
                "crossplane.io/managed-by": "kcl"
                "environment": "production"
            }
            labels = {
                "app": _name
                "component": "pipeline"
                "engine": "tekton"
            }
        }

        spec = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpec {
            engine = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecEngine {
                type = "tekton"
            }
            targetCluster = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTargetCluster {
                name = _targetClusterName
                scope = _targetClusterScope
            }
            tekton = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTekton {
                namespace = _tektonNamespace
                pipelineNamespace = _tektonPipelineNamespace
                version = _tektonVersion
                autoInstallComponents = True
                imagePullPolicy = _tektonImagePullPolicy
                enableTektonPipeline = True
                enableTektonTriggers = True
                enableTektonDashboard = True
                enableTektonPruner = True
                chartRepository = _tektonChartRepository
            }
        }
    }

# Minimal Template - Bare minimum required fields
if _templateName == "minimal":
    pipelinemod.PipelineIntegration {
        metadata = v1.ObjectMeta {
            name = _name
            namespace = _namespace
        }

        spec = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpec {
            engine = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecEngine {
                type = _engineType
            }
            targetCluster = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTargetCluster {
                name = _targetClusterName
            }
            tekton = pipelinemod.ResourcesStuttgartThingsComV1alpha1PipelineIntegrationSpecTekton {
                version = _tektonVersion
                enableTektonPipeline = True
            }
        }
    }
