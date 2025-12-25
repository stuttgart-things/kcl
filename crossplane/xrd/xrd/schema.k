"""
Crossplane CompositeResourceDefinition (XRD) v2 schema definitions
File: schema.k
"""

schema CompositeResourceDefinition:
    """
    Defines a Crossplane Composite Resource Definition v2
    """
    apiVersion: str = "apiextensions.crossplane.io/v2"
    kind: str = "CompositeResourceDefinition"
    metadata: Metadata
    spec: XRDSpec

schema Metadata:
    """
    Kubernetes metadata
    """
    name: str
    labels?: {str:str}
    annotations?: {str:str}

schema XRDSpec:
    """
    XRD v2 specification
    """
    group: str
    defaultCompositeDeletePolicy?: str
    scope?: str
    names: Names

schema Names:
    """
    Resource names definition
    """
    kind: str
    plural: str
    singular: str
    categories?: [str]
    shortNames?: [str]
