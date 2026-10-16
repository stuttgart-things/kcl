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
    # Three control-plane nodes, each etcd + control-plane + worker.
    #
    # Buildable since catalog 0.11.0 through the RANCHER custom-node path only
    # (rancher-k3s, rancher-rke2: multiNode = True) -- xplane-cluster >= 0.26.0
    # composes one VM per master and joins nodes 2..N after the first one.
    # Every other distribution still rejects it (assertSizeSupported). Limits
    # that remain: the API endpoint is the first node's IP
    # (crossplane-configurations#171), and a size cannot change after create
    # (#172).
    "medium-ha" = s.Size {
        cpu = "4"
        memory = "8192"
        disk = "64"
        masters = 3
    }
    # The app-cluster shape: three all-role nodes with room for a workload
    # platform on top (Argo CD AppSets, openebs, observability). NOT called
    # large-ha: a `<t-shirt>-ha` name reads as "that t-shirt, three times",
    # and this is neither medium (8192/64) nor large (8/16384). First order:
    # the LabDA rke2 app cluster (crossplane-configurations#170, #508).
    "app-ha" = s.Size {
        cpu = "4"
        memory = "12288"
        disk = "100"
        masters = 3
    }
}
