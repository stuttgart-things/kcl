# app-profile

KCL schema for **AppProfile**: one app of the [stuttgart-things/flux](https://github.com/stuttgart-things/flux)
catalog, both halves. It sits next to the component as `<bundle>/components/<app>/profile.yaml`
and says:
- which `postBuild.substitute` vars a cluster may set for the app, and which it must set;
- which Secret the app's `substituteFrom` reads, and how each value is made:
  generated, referenced from SOPS or Vault, or literal.

blueprints `render-cluster-apps` renders the bundle Kustomization and the SOPS-encrypted
Secret from it. Design: [stuttgart-things/blueprints#206](https://github.com/stuttgart-things/blueprints/issues/206).

```yaml
kind: AppProfile
metadata:
  name: keycloak
spec:
  bundle: apps-platform              # apps-platform | infra-platform | cicd-platform
  component: ../components/keycloak  # must be ../components/<metadata.name>
  vars:
    KEYCLOAK_STORAGE_CLASS: { required: true }
    KEYCLOAK_HOSTNAME: {}
  secrets:
    - name: keycloak-secrets
      data:
        ADMIN_USER: admin                                      # literal
        ADMIN_PASSWORD: { generate: { type: alnum, length: 32 } }
        ADMIN_TOKEN: ref+vault://secret/kc#/token              # bare ref
        ADMIN_KEY: { ref: "ref+sops://secrets/kc.enc.yaml#/key" }
```

## Validate

```bash
kcl mod pull oci://ghcr.io/stuttgart-things/app-profile --tag 0.1.0
kcl vet profile.yaml oci/ghcr.io/stuttgart-things/app-profile/0.1.0/main.k -s AppProfile --format yaml
```

Rejected, among others:
- unknown fields, e.g. `generat:` or `requird:`
- an unknown generate `type`, a `password` shorter than 4, `charset` on `hex`/`base64`/`uuid`
- a value with two kinds at once, e.g. `value` and `ref`
- a `ref+...` string that is not `ref+sops://<path>#/<pointer>` or `ref+vault://<path>#/<field>`
- var names and secret keys that are not variable names (`substituteFrom` turns keys into variables)
- a duplicate secret name
- a `component` that does not match `metadata.name`, or an unknown bundle

**Out of scope:** whether the vars and keys match what the component actually reads.
That needs the component itself, so the catalog checks it in `hack/check-app-profiles.py`.

## Note for editing `main.k`

`kcl vet` (kcl 0.12.4) does not evaluate module-level variables. A pattern or lambda defined at
the top of the file would be empty inside a `check`, and a regex check against it passes
everything. So every pattern is written into its check.
