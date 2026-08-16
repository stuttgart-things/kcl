import ..schema as s

# nfs-csi — https://github.com/stuttgart-things/flux/tree/main/infra/nfs-csi
#
# A StorageClass backed by an existing NFS export. Two required variables and
# nothing else: which server, which share. Both are facts about the network the
# cluster sits in, not about the cluster, so no source can discover them.
nfsCsi: s.App = {
    artifact = "oci://ghcr.io/stuttgart-things/flux/infra/nfs-csi"
    defaultVersion = "v1.18.1"
    components = [
        s.Component {
            name = "install"
            path = "./"
            wrapsHelmRelease = True
            timeout = "15m"
            requiredSubstitutions = ["NFS_SERVER_FQDN", "NFS_SHARE_PATH"]
        }
    ]
}
