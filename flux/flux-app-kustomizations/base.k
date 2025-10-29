"""
Flux Applications - Base Configuration
Shared configuration and helper functions
"""

# Common Configuration
flux_namespace: str = option("flux_namespace") or "flux-system"
source_repo_name: str = option("source_repo_name") or "flux-apps"
source_repo_kind: str = option("source_repo_kind") or "GitRepository"
default_interval: str = option("default_interval") or "1h"
default_retry_interval: str = option("default_retry_interval") or "1m"
default_timeout: str = option("default_timeout") or "5m"
