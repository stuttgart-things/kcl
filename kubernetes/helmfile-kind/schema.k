"""
Generic and flexible schema for Helmfile configuration
"""

schema HelmDefaults:
    """HelmDefaults defines default settings for all helm releases"""
    verify?: bool
    wait?: bool
    timeout?: int
    recreatePods?: bool
    force?: bool


schema HelmfileEntry:
    """HelmfileEntry represents a single helmfile with its configuration"""
    path: str
    values?: [{str: any}]  # list of arbitrary key-value maps


schema HelmfileConfig:
    """HelmfileConfig is the root configuration for helmfile"""
    helmDefaults?: HelmDefaults
    helmfiles: [HelmfileEntry]
