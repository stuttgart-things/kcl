# xrd

Renders a Crossplane [`CompositeResourceDefinition`](https://docs.crossplane.io/latest/concepts/composite-resource-definitions/)
(`apiextensions.crossplane.io/v2`) from a handful of options, so an XRD can be
produced without writing the CRD boilerplate by hand.

## Use

```bash
kcl run . -D group=resources.example.com -D kind=MyResource \
          -D plural=myresources -D singular=myresource
```

With no options at all the module renders the example XRD below — the four
required fields carry the values from that usage line as defaults, so a bare
`kcl run .` works and CI can smoke-test the module.

## Parameters

| key | default | |
|---|---|---|
| `group` | `resources.example.com` | API group |
| `kind` | `MyResource` | composite kind |
| `plural` | `myresources` | |
| `singular` | `myresource` | |
| `name` | `<plural>.<group>` | derived when not given |
| `scope` | `Namespaced` | `Namespaced` or `Cluster` |
| `deletePolicy` | `Foreground` | `defaultCompositeDeletePolicy` |
| `labels` | — | metadata labels; omitted when empty |
| `annotations` | — | metadata annotations; omitted when empty |
| `categories` | — | `names.categories`; omitted when empty |
| `shortNames` | — | `names.shortNames`; omitted when empty |

The five optional entries are spread in conditionally, so an unset one produces
no key at all rather than an empty list.

## Output

```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: myresources.resources.example.com
spec:
  group: resources.example.com
  defaultCompositeDeletePolicy: Foreground
  scope: Namespaced
  names:
    kind: MyResource
    plural: myresources
    singular: myresource
```

## Layout

```
main.k     reads the options and assembles the XRD
schema.k   CompositeResourceDefinition, XRDSpec, Names, Metadata
yaml/      reference XRDs
```
