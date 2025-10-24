"""
Flux Applications - Top Level Configuration
Usage:
  kcl run main.k -D enable_tekton=true -D enable_crossplane=true
"""

# ============================================================================
# Enable/Disable Applications
# ============================================================================
enable_tekton: bool = option("enable_tekton") or False
enable_crossplane: bool = option("enable_crossplane") or False

# ============================================================================
# Always import base and individual apps
# ============================================================================
import base
import tekton
import crossplane

# ============================================================================
# Conditionally build kubernetes resources list
# ============================================================================
kubernetes = [
    item
    for items in [
        tekton.kubernetes if enable_tekton else [],
        crossplane.kubernetes if enable_crossplane else [],
    ]
    for item in items
]