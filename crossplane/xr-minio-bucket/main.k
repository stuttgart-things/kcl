"""
MinioBucket orders (storage.stuttgart-things.com/v1alpha1) for the
crossplane-configurations storage/minio Composition, through
claim-machinery-api and machinery-order-service (stuttgart-things#4822).

Every parameter comes as its own option (-D key=value, which is how
claim-machinery-api passes them) or inside option("params"). The logic is in
render/render.k; tests/ renders it against hand-written buckets.

Output: a YAML stream with one MinioBucket XR -> the order file (source-path).
"""

import manifests
import render

_params = option("params") or {}

_KEYS = [
    "name"
    "provider_config"
    "deletion_policy"
    "region"
    "user"
    "access_name"
    "secret_namespace"
    "management_cluster"
    "source_path"
    "requested_by"
    "owner"
    "order_id"
]

# -D first, then params.
_p = {k = option(k) if option(k) not in [None, Undefined, ""] else _params?[k] for k in _KEYS}

manifests.yaml_stream(render.render(_p))
