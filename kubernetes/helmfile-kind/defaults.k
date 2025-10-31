import .schema

_helmDefaults = schema.HelmDefaults {
    verify = False
    wait = True
    timeout = 600
    recreatePods = False
    force = True
}
