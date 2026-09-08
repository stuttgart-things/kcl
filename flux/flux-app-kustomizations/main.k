"""
Flux Applications - Top Level Configuration
Usage:
  kcl main.k -D enable_tekton=true -D enable_crossplane=true
"""

# Private variables (underscore prefix means not exported)
_enable_tekton: bool = option("enable_tekton") or False
_enable_crossplane: bool = option("enable_crossplane") or False

# base.k, tekton.k and crossplane.k are siblings in this package, so their
# values are already in scope -- importing them would be a self-import and
# a redeclaration.
kubernetes = (tekton_kubernetes if _enable_tekton else []) + (crossplane_kubernetes if _enable_crossplane else [])
