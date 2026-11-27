# Golden tests: the module against hand-written MinioBuckets in
# stuttgart-things/stuttgart-things (copied verbatim to testdata/, commit
# 132f474c5). Run with `kcl test ./...` from the module directory.
import file
import yaml
import render

# The hand-written documents of a fixture, by XR name.
_fixture = lambda f: str -> {str:} {
    {d.metadata.name = d for d in yaml.decode_all(file.read("tests/testdata/${f}")) if d}
}

# What the module writes on top of a hand-written XR: the XRD's default
# deletionPolicy made explicit (the PR shows what a teardown does), and no
# metadata.namespace (the XR is cluster-scoped; the hand-written ones carry a
# meaningless `namespace: default`).
_expected = lambda d: {str:} -> {str:} {
    {
        apiVersion = d.apiVersion
        kind = d.kind
        metadata = {name = d.metadata.name, annotations = d.metadata.annotations}
        spec = d.spec | {deletionPolicy = "Orphan"}
    }
}

# labda-infra-zitadel-backup: a bucket on the LabDA MinIO with one user whose
# keys land in default/<bucket> -- exactly what an order makes.
test_golden_zitadel_backup_labda = lambda {
    _want = _expected(_fixture("minio-zitadel-backup.yaml")["labda-infra-zitadel-backup"])
    _got = render.render({
        name = "labda-infra-zitadel-backup"
        provider_config = "minio-labda"
        access_name = "backup"
        management_cluster = "machinery"
        source_path = "clusters/labda/vsphere/machinery-xrs/minio-zitadel-backup.yaml"
    })
    assert len(_got) == 1
    assert yaml.encode(_got[0], sort_keys=True) == yaml.encode(_want, sort_keys=True), "render differs from the hand-written XR:\n${yaml.encode(_got[0])}\n---\n${yaml.encode(_want)}"
}

# The same file's LabUL bucket: provider_config minio, from machinery.
test_golden_zitadel_backup_labul = lambda {
    _want = _expected(_fixture("minio-zitadel-backup.yaml")["labul-infra-zitadel-backup"])
    _got = render.render({
        name = "labul-infra-zitadel-backup"
        provider_config = "minio"
        access_name = "backup"
        source_path = "clusters/labda/vsphere/machinery-xrs/minio-zitadel-backup.yaml"
    })
    assert yaml.encode(_got[0], sort_keys=True) == yaml.encode(_want, sort_keys=True)
}

# homerun2-visuals: identical apart from bucketPolicy (anonymous GetObject),
# which an order does not offer.
test_golden_homerun2_visuals_without_bucket_policy = lambda {
    _d = _fixture("minio-homerun2-visuals.yaml")["homerun2-visuals"]
    _want = _expected(_d | {spec = {k = v for k, v in _d.spec if k != "bucketPolicy"}})
    _got = render.render({
        name = "homerun2-visuals"
        provider_config = "minio"
        source_path = "clusters/labda/vsphere/machinery-xrs/minio-homerun2-visuals.yaml"
    })
    assert yaml.encode(_got[0], sort_keys=True) == yaml.encode(_want, sort_keys=True)
}

# An order as machinery-order-service places it (#4822 acceptance).
test_order = lambda {
    _xr = render.render({
        name = "mos-test1"
        deletion_policy = "DeleteIfEmpty"
        order_id = "ord-0123456789ab"
        requested_by = "user:default/patrick.hermann"
        owner = "group:default/platform"
        management_cluster = "machinery"
        source_path = "clusters/labda/vsphere/machinery-orders-xrs/mos-test1.yaml"
    })[0]
    assert _xr.metadata.labels["stuttgart-things.com/order-id"] == "ord-0123456789ab"
    assert _xr.metadata.annotations["stuttgart-things.com/order-id"] == "ord-0123456789ab"
    assert _xr.metadata.annotations["stuttgart-things.com/requested-by"] == "user:default/patrick.hermann"
    assert _xr.metadata.annotations["stuttgart-things.com/owner"] == "group:default/platform"
    assert _xr.metadata.annotations["stuttgart-things.com/source-path"] == "clusters/labda/vsphere/machinery-orders-xrs/mos-test1.yaml"
    assert _xr.spec.deletionPolicy == "DeleteIfEmpty"
    assert _xr.spec.providerConfigRef.name == "minio-labda"
    assert "namespace" not in _xr.metadata
}

# Defaults: Orphan, LabDA MinIO, the orders directory of machinery, owner = orderer.
test_defaults = lambda {
    _xr = render.render({name = "bk1", requested_by = "user:default/x"})[0]
    assert _xr.spec.deletionPolicy == "Orphan"
    assert _xr.spec.providerConfigRef.name == "minio-labda"
    assert _xr.metadata.annotations["stuttgart-things.com/source-path"] == "clusters/labda/vsphere/machinery-orders-xrs/minio-bk1.yaml"
    assert _xr.metadata.annotations["stuttgart-things.com/owner"] == "user:default/x"
    assert "labels" not in _xr.metadata
    _labul = render.render({name = "bk1", management_cluster = "machinery-labul", provider_config = "minio"})[0]
    assert _labul.metadata.annotations["stuttgart-things.com/source-path"] == "clusters/labul/proxmox/machinery-labul-orders-xrs/minio-bk1.yaml"
}

# user=false (also as the string -D passes): the bucket alone, no access.
test_no_user = lambda {
    assert "access" not in render.render({name = "bk1", user = False})[0].spec
    assert "access" not in render.render({name = "bk1", user = "false"})[0].spec
}
