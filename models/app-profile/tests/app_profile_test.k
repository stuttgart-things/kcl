# Tests for the AppProfile schema. The negative cases need `kcl vet` (a failed
# check aborts the run), see README.md.
import ..main as ap

test_profile_with_every_value_kind = lambda {
    p = ap.AppProfile {
        kind = "AppProfile"
        metadata = {name = "keycloak"}
        spec = {
            bundle = "apps-platform"
            component = "../components/keycloak"
            vars = {
                KEYCLOAK_STORAGE_CLASS = {required = True}
                KEYCLOAK_HOSTNAME = {}
                KEYCLOAK_VERSION = {default = "25.2.0"}
            }
            secrets = [
                {
                    name = "keycloak-secrets"
                    data = {
                        ADMIN_USER = "admin"
                        ADMIN_PASSWORD = {generate = {$type = "alnum", length = 32}}
                        ADMIN_TOKEN = "ref+vault://secret/kc#/token"
                        ADMIN_KEY = {ref = "ref+sops://secrets/kc.enc.yaml#/key"}
                        ADMIN_EMAIL = {value = "admin@example.com"}
                    }
                }
            ]
        }
    }
    assert p.spec.vars.KEYCLOAK_STORAGE_CLASS.required == True
    assert len(p.spec.secrets[0].data) == 5
}

test_profile_without_secrets = lambda {
    p = ap.AppProfile {
        kind = "AppProfile"
        metadata = {name = "headlamp"}
        spec = {
            bundle = "infra-platform"
            component = "../components/headlamp"
        }
    }
    assert p.spec.bundle == "infra-platform"
}
