# T-shirt sizes.
#
# Values are a deliberate rounding of what the fleet actually runs, not new
# invention: `small` is the vspherevm XRD default (2/4096), `medium` matches
# nativeproxmoxvm-u26-eva (6/6144/40) rounded to 4/8192, `large` matches
# nativevspherevm-kind-test1 (8/16384/100), which is sized for a kind cluster
# plus crossplane + flux + the app catalog on top.
import schema as s

sizeTable: {str:s.Size} = {
    small = s.Size {
        cpu = "2"
        memory = "4096"
        disk = "40"
    }
    medium = s.Size {
        cpu = "4"
        memory = "8192"
        disk = "64"
    }
    large = s.Size {
        cpu = "8"
        memory = "16384"
        disk = "100"
    }
    # Three control-plane nodes. Gated on crossplane-configurations#170 (static
    # addressing + aggregate ready gate) AND #171 (the API endpoint is a single
    # node IP today, so 3 masters would be HA in name only). Present so the
    # shape is reviewable; a consumer without those must reject masters > 1.
    "medium-ha" = s.Size {
        cpu = "4"
        memory = "8192"
        disk = "64"
        masters = 3
    }
}
