# T-shirt sizes.
#
# Values are a deliberate rounding of what the fleet actually runs, not new
# invention: `small` is the vspherevm XRD default (2/4096), `medium` matches
# nativeproxmoxvm-u26-eva (6/6144/40) rounded to 4/8192, `large` matches
# nativevspherevm-kind-test1 (8/16384/100), which is sized for a kind cluster
# plus crossplane + flux + the app catalog on top.
#
# A size is the shape of ONE node (catalog 0.12.0). How many nodes a cluster
# gets is the order's `nodes` -- see getShape in main.k.
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
    # Between medium and large: medium's cores with half again the memory and
    # the disk of large -- room for a workload platform on top (Argo CD
    # AppSets, openebs, observability). The per-node shape of the LabDA app
    # cluster (crossplane-configurations#170, #508); `nodes: 3` makes it that
    # cluster. Named after what differs from medium (memory), not after a
    # node count: a size is ONE node since catalog 0.12.0.
    "medium-mem" = s.Size {
        cpu = "4"
        memory = "12288"
        disk = "100"
    }
    # --- Deprecated aliases (catalog 0.12.0) ----------------------------------
    # Until 0.11.0 a size carried the node count too. Since 0.12.0 a size is the
    # shape of ONE node and the count is the order's `nodes` (getShape). These
    # two stay because `size` is immutable on the cluster XRD (#172) and a live
    # order uses one (labda-apps-test1, app-ha) -- removing them would fail its
    # next render. Each is EXACTLY its t-shirt times `masters`, which a test
    # asserts, so `size: medium-mem, nodes: 3` renders the same children as
    # `size: app-ha`. Do not add new aliases; write `size` + `nodes`.
    "medium-ha" = s.Size {
        cpu = "4"
        memory = "8192"
        disk = "64"
        masters = 3
        aliasOf = "medium"
    }
    "app-ha" = s.Size {
        cpu = "4"
        memory = "12288"
        disk = "100"
        masters = 3
        aliasOf = "medium-mem"
    }
}
