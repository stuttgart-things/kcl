import ..schema as s

# vspherevm — provider-vspherevm + the vspherevm Configuration.
#
# Second entry deliberately: one capability cannot show whether the schema
# generalizes. It differs from proxmoxvm in every part that matters — a
# different provider group, four Vault keys instead of five under different
# names, a flat JSON without SSH credentials, and placement by folder/pool
# rather than node/datastore.
vspherevm: s.Capability = {
    name = "vspherevm"
    providerConfig = s.ProviderConfig {
        apiVersion = "vspherevm.m.stuttgart-things.com/v1beta1"
    }
    credentials = s.Credentials {
        data = {
            credentials = '{"user":"{{ .vsphere_user }}","password":"{{ .vsphere_password }}","server":"{{ .vsphere_server }}","allow_unverified_ssl":"true"}'
        }
        vaultKeys = ["vsphere_user", "vsphere_password", "vsphere_server"]
    }
    environmentLabelKey = "vspherevm.resources.stuttgart-things.com/environment"
    # MOIDs, not names: vSphere placement is by managed-object ID
    # (datastore-12, resgroup-8, dvportgroup-2048), and templateUuid is the
    # BIOS config.uuid rather than the VM name.
    required = ["templateUuid", "datastoreId", "resourcePoolId", "networkId", "folder", "domain"]
    defaults = {
        firmware = "bios"
        guestId = "ubuntu64Guest"
        scsiType = "pvscsi"
        adapterType = "vmxnet3"
        annotation = "VSPHERE-VM BUILD w/ CROSSPLANE FOR STUTTGART-THINGS"
    }
    optional = ["hostSystemId"]
}
