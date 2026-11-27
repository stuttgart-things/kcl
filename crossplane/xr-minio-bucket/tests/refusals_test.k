# Refusals: each of these must fail the render. Run with `kcl test ./...`.
import runtime
import render

# runtime.catch returns the failure's message, or Undefined if there is none.
_refused = lambda p: {str:} -> bool {
    _err = runtime.catch(lambda {
        render.render(p)
    })
    typeof(_err) == "str" and _err != ""
}

test_refuses_delete_all = lambda {
    assert _refused({name = "bk1", deletion_policy = "DeleteAll"})
}

test_refuses_unknown_deletion_policy = lambda {
    assert _refused({name = "bk1", deletion_policy = "Delete"})
}

test_refuses_minio_labda_on_machinery_labul = lambda {
    assert _refused({name = "bk1", management_cluster = "machinery-labul", provider_config = "minio-labda"})
}

test_refuses_unknown_provider_config = lambda {
    assert _refused({name = "bk1", provider_config = "minio-other"})
}

test_refuses_bad_names = lambda {
    assert _refused({name = "ab"})
    assert _refused({name = "Bucket"})
    assert _refused({name = "my.bucket"})
    assert _refused({name = "-bucket"})
    assert _refused({name = "xn--bucket"})
    # 51 characters: over machinery-order-service's limit; 50 pass.
    assert _refused({name = "a" * 51})
    assert not _refused({name = "a" * 50})
}

test_refuses_unknown_cluster_without_source_path = lambda {
    assert _refused({name = "bk1", management_cluster = "elsewhere"})
    assert not _refused({name = "bk1", management_cluster = "elsewhere", source_path = "x/bk1.yaml"})
}

test_accepts_the_allowed = lambda {
    assert not _refused({name = "bk1"})
    assert not _refused({name = "bk1", deletion_policy = "DeleteIfEmpty", provider_config = "minio"})
    assert not _refused({name = "bk1", management_cluster = "machinery-labul", provider_config = "minio"})
}
