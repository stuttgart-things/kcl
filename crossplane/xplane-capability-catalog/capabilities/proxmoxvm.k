import ..schema as s

# proxmoxvm — provider-proxmox-bpg + the proxmoxvm Configuration.
#
# Placement fields are transcribed from the capability Helm chart
# (stuttgart-things/stuttgart-things, crossplane/platform/capabilities/proxmoxvm),
# which is the shape the proxmoxvm Composition already reads. Deviating from it
# would not be a redesign, it would be a silent break: the Composition looks the
# keys up by name.
proxmoxvm: s.Capability = {
    name = "proxmoxvm"
    providerConfig = s.ProviderConfig {
        apiVersion = "proxmoxbpg.m.crossplane.io/v1beta1"
    }
    credentials = s.Credentials {
        # ONE key holding JSON — the bpg provider parses this document, it does
        # not read a Secret with one key per field.
        #
        # `insecure` is the string "true", not the boolean. The provider
        # unmarshals into a string field, and a bare true fails the parse with a
        # type error that names neither the field nor this Secret.
        data = {
            credentials = '{"endpoint":"{{ .pve_api_url }}","username":"{{ .pve_api_user }}","password":"{{ .pve_api_password }}","insecure":"true","ssh_username":"{{ .vm_ssh_user }}","ssh_password":"{{ .vm_ssh_password }}"}'
        }
        vaultKeys = ["pve_api_url", "pve_api_user", "pve_api_password", "vm_ssh_user", "vm_ssh_password"]
    }
    # The cloud-init password. Same Vault secret as the credentials, different
    # namespace: the namespaced EnvironmentVM CRD resolves passwordSecretRef in
    # the managed resource's own namespace, i.e. the XR's, not the provider's.
    workloadSecrets = [
        s.WorkloadSecret {
            nameSuffix = "ci-password"
            data = {password = "{{ .vm_ssh_password }}"}
            vaultKeys = ["vm_ssh_password"]
        }
    ]
    environmentLabelKey = "proxmoxvm.resources.stuttgart-things.com/environment"
    required = ["node", "datastore", "bridge", "vlanTag", "pool", "templateVmId"]
    defaults = {
        cpuType = "host"
        osType = "l26"
        bios = "seabios"
        # sthings-u26 carries its root disk on virtio0. scsi0 — the obvious
        # default — produces a VM that boots to no disk.
        diskInterface = "virtio0"
        networkModel = "virtio"
        ciUsername = "sthings"
        ciPasswordSecretKey = "password"
        annotation = "PROXMOX-VM BUILD w/ CROSSPLANE (native) FOR STUTTGART-THINGS"
    }
    # cloneDatastore: bpg's clone block is ForceNew. A value here rewrites the
    # clone block of every VM already built under this EnvironmentConfig, and
    # the provider answers with destroy + recreate — unattended, under
    # compositionUpdatePolicy Automatic. Requires proxmoxvm >= v0.11.0, whose
    # `none` sentinel is how an individual XR declines it.
    #
    # cloudInitDatastore steuert das 4-MB-cidata-Image von der Datenplatte weg.
    # Es ist die eine Platte, die PVE bei jedem Stop/Start freigibt und neu
    # anlegt, und auf manchen Storages ist genau dieser Umlauf kaputt: auf LabULs
    # `V5010-01-1` kann PVE `/dev/V5010-01-1/vm-<id>-cloudinit.qcow2` nicht
    # statten, der Stop laesst das LV ohne Device-Node in den VG-Metadaten zurueck
    # und der naechste Start stirbt an `lvcreate ... already exists`. Die VM ist
    # dann nicht mehr bootbar. Am 2026-08-20 hostseitig bestaetigt: dieselbe VM
    # mit cidata auf dem NFS-Store `DD-sthings` stoppt und startet sauber.
    #
    # HIER, WEIL DIE COMPOSITION ES HIER SUCHT. proxmoxvm loest
    # `initialization.datastoreId` als spec.cloudInit.datastoreId ->
    # EnvironmentConfig `cloudInitDatastore` -> Datastore der Rootplatte auf. Der
    # Katalog kannte den Schluessel bis 0.5.0 nicht, also hat die von der
    # Capability erzeugte EnvironmentConfig ihn nie getragen und JEDE so gebaute
    # VM landete auf dem letzten Glied der Kette — dem kaputten Storage. Kein
    # Fehler, kein Hinweis im Status: die VM entsteht und wird erst beim ersten
    # Stop/Start unbootbar.
    #
    # Optional und ohne Default, obwohl LabUL `DD-sthings` will: ein
    # Storage-Name ist eine Standort-Wahrheit, keine strukturelle. Ein Katalog-
    # Default waere auf jedem anderen Proxmox-Cluster schlicht falsch.
    #
    # snippetsDatastore is NOT the hostname lever (that is the PVE VM name);
    # it only pins the cloud-init instance-id.
    optional = ["cloneDatastore", "cloudInitDatastore", "snippetsDatastore", "smbiosManufacturer", "smbiosProduct", "ciPasswordSecretName"]
}
