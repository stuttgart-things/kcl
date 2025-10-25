"""
Flux Applications - Top Level Configuration
Usage:
  kcl main.k -D enable_tekton=true -D enable_crossplane=true
"""

# Private variables (underscore prefix means not exported)
_enable_tekton: bool = option("enable_tekton") or False
_enable_crossplane: bool = option("enable_crossplane") or False

import base
import tekton
import crossplane

# Build kubernetes list on a single line or use list comprehension
kubernetes = (tekton.kubernetes if _enable_tekton else []) + (crossplane.kubernetes if _enable_crossplane else [])
