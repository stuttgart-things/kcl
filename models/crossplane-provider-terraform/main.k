# Crossplane Terraform Provider Module
# This module provides KCL resources for managing Terraform Workspaces via Crossplane

import models.v1beta1.tf_upbound_io_v1beta1_workspace as workspace
import k8s.api.core.v1 as corev1

# Main schema for Terraform Workspace configuration
schema TerraformWorkspace:
    """
    TerraformWorkspace defines a Terraform workspace managed through Crossplane.

    This schema provides a simplified interface for creating Terraform workspaces
    with common configurations while exposing the full Crossplane Terraform Provider API.
    """
    # Basic workspace configuration
    name: str
    namespace?: str = "default"
    labels?: {str: str}
    annotations?: {str: str}

    # Terraform configuration
    source: "Remote" | "Inline" | "Flux" = "Remote"
    module: str
    entrypoint?: str = ""
    inlineFormat?: "HCL" | "JSON" = "HCL"

    # Terraform variables
    variables?: {str: str}
    variableFiles?: [TerraformVarFile]
    environmentVariables?: [TerraformEnvVar]

    # CLI arguments
    initArgs?: [str] = []
    planArgs?: [str] = []
    applyArgs?: [str] = []
    destroyArgs?: [str] = []

    # Provider configuration
    providerConfigRef?: str = "default"

    # Connection secrets
    connectionSecret?: TerraformConnectionSecret

    # Management policies
    managementPolicies?: [str] = ["*"]
    deletionPolicy?: "Delete" | "Orphan" = "Delete"

    # Advanced options
    enableTerraformCLILogging?: bool = False

schema TerraformVarFile:
    """Configuration for Terraform variable files."""
    source: "ConfigMapKey" | "SecretKey"
    format?: "HCL" | "JSON" = "HCL"
    configMapRef?: ResourceReference
    secretRef?: ResourceReference

schema TerraformEnvVar:
    """Environment variable configuration for Terraform execution."""
    name: str
    value?: str
    configMapRef?: ResourceReference
    secretRef?: ResourceReference

schema ResourceReference:
    """Reference to a Kubernetes resource."""
    name: str
    namespace: str
    key: str

schema TerraformConnectionSecret:
    """Connection secret configuration for Terraform outputs."""
    name: str
    namespace?: str

# Helper function to generate Terraform Workspace resources
generateTerraformWorkspace = lambda config: TerraformWorkspace -> [workspace.Workspace] {
    """
    Generate a Crossplane Terraform Workspace resource from simplified configuration.

    Args:
        config: TerraformWorkspace configuration

    Returns:
        List containing the generated Workspace resource
    """

    # Build metadata
    metadata = {
        name = config.name
        namespace = config.namespace or "default"
        labels = config.labels or {}
        annotations = config.annotations or {}
    }

    # Build environment variables
    envVars = []
    if config.environmentVariables:
        envVars = [
            {
                name = env.name
                value = env.value
                configMapKeyRef = {
                    name = env.configMapRef.name
                    namespace = env.configMapRef.namespace
                    key = env.configMapRef.key
                } if env.configMapRef else Undefined
                secretKeyRef = {
                    name = env.secretRef.name
                    namespace = env.secretRef.namespace
                    key = env.secretRef.key
                } if env.secretRef else Undefined
            } for env in config.environmentVariables
        ]

    # Build variable files
    varFiles = []
    if config.variableFiles:
        varFiles = [
            {
                source = varFile.source
                format = varFile.format or "HCL"
                configMapKeyRef = {
                    name = varFile.configMapRef.name
                    namespace = varFile.configMapRef.namespace
                    key = varFile.configMapRef.key
                } if varFile.configMapRef else Undefined
                secretKeyRef = {
                    name = varFile.secretRef.name
                    namespace = varFile.secretRef.namespace
                    key = varFile.secretRef.key
                } if varFile.secretRef else Undefined
            } for varFile in config.variableFiles
        ]

    # Build variables
    vars = []
    if config.variables:
        vars = [
            {
                key = k
                value = v
            } for k, v in config.variables
        ]

    # Create the Workspace resource
    [
        workspace.Workspace {
            metadata = metadata
            spec = {
                deletionPolicy = config.deletionPolicy
                managementPolicies = config.managementPolicies
                providerConfigRef = {
                    name = config.providerConfigRef
                } if config.providerConfigRef else Undefined
                writeConnectionSecretToRef = {
                    name = config.connectionSecret.name
                    namespace = config.connectionSecret.namespace or config.namespace or "default"
                } if config.connectionSecret else Undefined
                forProvider = {
                    source = config.source
                    module = config.module
                    entrypoint = config.entrypoint
                    inlineFormat = config.inlineFormat if config.source == "Inline" else Undefined
                    env = envVars if envVars else Undefined
                    varFiles = varFiles if varFiles else Undefined
                    vars = vars if vars else Undefined
                    initArgs = config.initArgs if config.initArgs else Undefined
                    planArgs = config.planArgs if config.planArgs else Undefined
                    applyArgs = config.applyArgs if config.applyArgs else Undefined
                    destroyArgs = config.destroyArgs if config.destroyArgs else Undefined
                    enableTerraformCLILogging = config.enableTerraformCLILogging
                }
            }
        }
    ]
}

# Utility functions for common Terraform workspace patterns

# Simple Git-based Terraform workspace
gitTerraformWorkspace = lambda name: str, gitUrl: str, path: str, variables: {str: str} -> [workspace.Workspace] {
    """
    Create a simple Terraform workspace from a Git repository.

    Args:
        name: Workspace name
        gitUrl: Git repository URL
        path: Path within repository (use "" for root)
        variables: Terraform variables

    Returns:
        List containing the generated Workspace resource
    """

    module = gitUrl + ("/" + path if path else "")

    generateTerraformWorkspace(TerraformWorkspace {
        name = name
        source = "Remote"
        module = module
        variables = variables
    })
}

# Inline Terraform workspace
inlineTerraformWorkspace = lambda name: str, terraformCode: str, format: str, variables: {str: str} -> [workspace.Workspace] {
    """
    Create a Terraform workspace with inline Terraform code.

    Args:
        name: Workspace name
        terraformCode: Inline Terraform code
        format: Code format (HCL or JSON)
        variables: Terraform variables

    Returns:
        List containing the generated Workspace resource
    """

    generateTerraformWorkspace(TerraformWorkspace {
        name = name
        source = "Inline"
        module = terraformCode
        inlineFormat = format
        variables = variables
    })
}

# Terraform workspace with secrets
secretTerraformWorkspace = lambda name: str, gitUrl: str, secretName: str, secretNamespace: str, variables: {str: str} -> [workspace.Workspace] {
    """
    Create a Terraform workspace with connection secrets for outputs.

    Args:
        name: Workspace name
        gitUrl: Git repository URL
        secretName: Name for connection secret
        secretNamespace: Namespace for connection secret
        variables: Terraform variables

    Returns:
        List containing the generated Workspace resource
    """

    generateTerraformWorkspace(TerraformWorkspace {
        name = name
        source = "Remote"
        module = gitUrl
        variables = variables
        connectionSecret = TerraformConnectionSecret {
            name = secretName
            namespace = secretNamespace
        }
    })
}
