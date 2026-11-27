"""
MinioBucket orders (storage.stuttgart-things.com/v1alpha1, crossplane-configurations
storage/minio) as a lambda, so main.k renders one order and the tests render many.

render(p) takes the parameters as claim-machinery-api passes them (one value per
key; -D turns "true" into a bool and digits into ints, so everything goes
through str()) and returns the documents to write: today one XR.
"""
import regex

# A value counts as set unless it is missing, None or "".
_isSet = lambda v -> bool {
    v != None and v != Undefined and v != ""
}

_str = lambda p: {str:}, k: str, fallback: str -> str {
    _v = p?[k]
    str(_v) if _isSet(_v) else fallback
}

_bool = lambda p: {str:}, k: str, fallback: bool -> bool {
    _v = p?[k]
    (str(_v).lower() in ["true", "1", "yes"]) if _isSet(_v) else fallback
}

# provider-minio ProviderConfigs. The NAME means the same MinIO on every
# management cluster: `minio` is the LabUL MinIO (platform-sthings), on
# machinery and machinery-labul alike; `minio-labda` is the LabDA MinIO
# (sthings-platform) and exists on machinery only.
PROVIDER_CONFIGS: {str:[str]} = {
    "machinery" = ["minio-labda", "minio"]
    "machinery-labul" = ["minio"]
}

# Where each management cluster's orders live (one file per order, no
# kustomization.yaml; the same directories as xr-native-vm).
ORDERS_DIRS: {str:str} = {
    "machinery" = "clusters/labda/vsphere/machinery-orders-xrs"
    "machinery-labul" = "clusters/labul/proxmox/machinery-labul-orders-xrs"
}

# What deleting the XR does to the BUCKET (the XRD's spec.deletionPolicy):
#   Orphan        (default) the bucket and its objects stay on the MinIO
#   DeleteIfEmpty the bucket goes only if it is empty; a full one is refused
#                 by MinIO (BucketNotEmpty), the composed Bucket keeps its
#                 finalizer and nothing is lost
# DeleteAll (bucket AND every object) is never offered by an order: whoever
# needs it writes the XR by hand.
DELETION_POLICIES = ["Orphan", "DeleteIfEmpty"]

render = lambda p: {str:} -> [{str:}] {
    _name = _str(p, "name", "demo-bucket")
    assert regex.match(_name, r"^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$"), "name must be 3-63 characters of a-z, 0-9 and -, starting and ending alphanumeric, got ${_name}"
    # MinIO reserves these prefixes; S3 refuses an IP-like name, which the
    # pattern above (no dots) already rules out.
    assert not _name.startswith("xn--") and not _name.startswith("sthree-"), "name must not start with xn-- or sthree-, got ${_name}"

    _cluster = _str(p, "management_cluster", "machinery")
    _providerConfig = _str(p, "provider_config", "minio-labda")
    assert _providerConfig in ["minio-labda", "minio"], "provider_config must be minio-labda or minio, got ${_providerConfig}"
    # A management cluster not listed above is not checked: its
    # ProviderConfigs are not known here.
    _allowed = PROVIDER_CONFIGS[_cluster] if _cluster in PROVIDER_CONFIGS else [_providerConfig]
    assert _providerConfig in _allowed, "provider_config ${_providerConfig} does not exist on ${_cluster} (there: ${', '.join(_allowed)})"

    _deletionPolicy = _str(p, "deletion_policy", "Orphan")
    assert _deletionPolicy != "DeleteAll", "deletion_policy DeleteAll is not offered by an order: it deletes every object in the bucket"
    assert _deletionPolicy in DELETION_POLICIES, "deletion_policy must be Orphan or DeleteIfEmpty, got ${_deletionPolicy}"

    _region = _str(p, "region", "us-east-1")
    _user = _bool(p, "user", True)
    _accessName = _str(p, "access_name", "writer")
    assert regex.match(_accessName, r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"), "access_name must be a-z, 0-9 and -, got ${_accessName}"
    _secretNamespace = _str(p, "secret_namespace", "default")

    _ordersDir = ORDERS_DIRS[_cluster] if _cluster in ORDERS_DIRS else ""
    _sourcePath = _str(p, "source_path", "${_ordersDir}/minio-${_name}.yaml" if _ordersDir else "")
    assert _sourcePath, "source_path is required for management cluster ${_cluster} (no orders directory known)"

    # Who ordered, for whom, and the order (#4276, #4296).
    _requestedBy = _str(p, "requested_by", "")
    _owner = _str(p, "owner", _requestedBy)
    _orderId = _str(p, "order_id", "")

    _xr = {
        apiVersion = "storage.stuttgart-things.com/v1alpha1"
        kind = "MinioBucket"
        # Cluster-scoped XR (provider-minio is a pre-v2 provider): no namespace.
        metadata = {
            name = _name
            if _orderId:
                labels = {"stuttgart-things.com/order-id" = _orderId}
            annotations = {
                "stuttgart-things.com/management-cluster" = _cluster
                # The file this XR lives in: deleting removes the file first.
                "stuttgart-things.com/source-path" = _sourcePath
                if _requestedBy:
                    "stuttgart-things.com/requested-by" = _requestedBy
                if _owner:
                    "stuttgart-things.com/owner" = _owner
                # The orders do not prune: deleting is file first, then the XR.
                "kustomize.toolkit.fluxcd.io/prune" = "disabled"
                if _orderId:
                    "stuttgart-things.com/order-id" = _orderId
            }
        }
        spec = {
            providerConfigRef = {name = _providerConfig}
            bucketName = _name
            region = _region
            # Always written, also the default: the PR shows what a teardown
            # does to the data.
            deletionPolicy = _deletionPolicy
            if _user:
                # One user with every operation on this bucket and nothing
                # else; its keys in Secret <secret_namespace>/<name> on the
                # management cluster (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY).
                access = [{
                    name = _accessName
                    scope = "bucket"
                    connectionSecret = {
                        name = _name
                        namespace = _secretNamespace
                    }
                }]
        }
    }
    [_xr]
}
