"""
The stuttgart-things capability catalog.

Consumers import `catalog` (or call `get`) and combine an entry with the
per-cluster values on an XR. See schema.k for what belongs here and what does
not.
"""

import .schema as s
import .capabilities.proxmoxvm as proxmoxvm
import .capabilities.vspherevm as vspherevm

catalog: {str:s.Capability} = {
    proxmoxvm = proxmoxvm.proxmoxvm
    vspherevm = vspherevm.vspherevm
}

names: [str] = sorted([n for n in catalog])

get = lambda name: str -> s.Capability {
    assert name in catalog, "unknown capability '" + name + "' — known: " + ", ".join(names)
    catalog[name]
}

# Every placement field a capability can emit, in one list. A consumer needs
# this to reject an XR key that matches nothing: a typo'd `datastoreID` would
# otherwise be dropped in silence and surface as a provider error naming a field
# the user never wrote.
fields = lambda name: str -> [str] {
    _c = get(name)
    _c.required + sorted([k for k in _c.defaults]) + _c.optional
}
