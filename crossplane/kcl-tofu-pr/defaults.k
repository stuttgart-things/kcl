# Static, non-field pipeline-run settings.
# Per-field default values live in main.k (single source of truth).
_task_run_template = {
    serviceAccountName = "default"
}

_timeouts = {
    pipeline = "1h0m0s"
}
