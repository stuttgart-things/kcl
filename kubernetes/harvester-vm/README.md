# HARVESTER-VM

## PVC

```bash
kcl run main.k \
  -D enableVm=false \
  -D enableCloudConfig=false \
  -D enablePvc=true \
  -D name=dev2-disk-0 \
  -D namespace=default \
  -D imageNamespace=default \
  -D imageId=image-t9w92 \
  -D storage=10Gi \
  -D storageClass=longhorn \
  -D volumeMode=Block \
  -D 'accessModes=["ReadWriteMany"]' \
  --format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}'
```

## CLOUD CONFIG SECRET

```bash
CLOUDCFG_B64=$(cat <<'EOF' | base64 -w0
#cloud-config
hostname: dev4
ssh_pwauth: true
users:
  - name: sthings
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...
chpasswd:
  list: |
    sthings:Test123
  expire: false

package_update: true
packages:
  - qemu-guest-agent
runcmd:
  - - systemctl
    - enable
    - --now
    - qemu-guest-agent.service
EOF
)
```

```bash
kcl run main.k \
  -D enableVm=false \
  -D enablePvc=false \
  -D enableCloudConfig=true \
  -D userdata=${CLOUDCFG_B64} \
  --format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}'
```

## VM

```bash
kcl run main.k \
  -D enablePvc=false \
  -D enableCloudConfig=false \
  -D enableVm=true \
  -D vmName=dev2 \
  -D namespace=default \
  -D hostname=dev2 \
  -D description="dev2 vm" \
  -D osLabel=linux \
  -D runStrategy=RerunOnFailure \
  -D cpuCores=8 \
  -D cpuSockets=1 \
  -D cpuThreads=1 \
  -D memory=12Gi \
  -D pvcName=dev2-disk-0 \
  -D secretName=dev4 \
  -D networkName=vms \
  -D evictionStrategy=LiveMigrateIfPossible \
  -D terminationGracePeriod=120 \
--format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}'
```

## ALL RESOURCES (PVC + CloudConfig Secret + VM)

### Using parameters file

```bash
# First, create cloud-config data
CLOUDCFG_B64=$(cat <<'EOF' | base64 -w0
#cloud-config
hostname: dev5
ssh_pwauth: true
users:
  - name: sthings
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...
chpasswd:
  list: |
    sthings:Test123
  expire: false

package_update: true
packages:
  - qemu-guest-agent
runcmd:
  - - systemctl
    - enable
    - --now
    - qemu-guest-agent.service
EOF
)

# Render all resources using parameters file
dagger call -m github.com/stuttgart-things/dagger/kcl run \
  --oci-source ghcr.io/stuttgart-things/harvester-vm:0.1.0 \
  --parameters-file params.yaml \
  --parameters "userdata=${CLOUDCFG_B64}" \
  export --path /tmp/harvester-dev5.yaml
```

### Using parameters only (no file)

```bash
# First, create cloud-config data
CLOUDCFG_B64=$(cat <<'EOF' | base64 -w0
#cloud-config
hostname: dev5
ssh_pwauth: true
users:
  - name: sthings
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...
chpasswd:
  list: |
    sthings:Test123
  expire: false

package_update: true
packages:
  - qemu-guest-agent
runcmd:
  - - systemctl
    - enable
    - --now
    - qemu-guest-agent.service
EOF
)

# Render all resources with Dagger
dagger call -m github.com/stuttgart-things/dagger/kcl run \
  --oci-source ghcr.io/stuttgart-things/harvester-vm:0.1.0 \
  --parameters "enablePvc=true,enableCloudConfig=true,enableVm=true,name=dev5-disk-0,namespace=default,imageNamespace=default,imageId=image-t9w92,storage=20Gi,storageClass=longhorn,volumeMode=Block,accessModes=[\"ReadWriteMany\"],userdata=${CLOUDCFG_B64},secretName=dev5-cloud-init,vmName=dev5,hostname=dev5,description=dev5-complete-vm-setup,osLabel=linux,runStrategy=RerunOnFailure,cpuCores=4,cpuSockets=1,cpuThreads=1,memory=8Gi,pvcName=dev5-disk-0,networkName=vms,evictionStrategy=LiveMigrateIfPossible,terminationGracePeriod=120" \
  export --path /tmp/harvester-dev5.yaml
```

### Override parameters from file

```bash
# Use parameters file but override specific values via CLI
dagger call -m github.com/stuttgart-things/dagger/kcl run \
  --oci-source ghcr.io/stuttgart-things/harvester-vm:0.1.0 \
  --parameters-file params.yaml \
  --parameters "userdata=${CLOUDCFG_B64},cpuCores=8,memory=16Gi" \
  export --path /tmp/harvester-dev5.yaml
```

Note: CLI parameters (`--parameters`) override values from `--parameters-file`.

### Alternative: Using KCL directly

```bash
# Render all resources
kcl run main.k \
  -D enablePvc=true \
  -D enableCloudConfig=true \
  -D enableVm=true \
  -D name=dev5-disk-0 \
  -D namespace=default \
  -D imageNamespace=default \
  -D imageId=image-t9w92 \
  -D storage=20Gi \
  -D storageClass=longhorn \
  -D volumeMode=Block \
  -D 'accessModes=["ReadWriteMany"]' \
  -D userdata=${CLOUDCFG_B64} \
  -D secretName=dev5-cloud-init \
  -D vmName=dev5 \
  -D hostname=dev5 \
  -D description="dev5 complete vm setup" \
  -D osLabel=linux \
  -D runStrategy=RerunOnFailure \
  -D cpuCores=4 \
  -D cpuSockets=1 \
  -D cpuThreads=1 \
  -D memory=8Gi \
  -D pvcName=dev5-disk-0 \
  -D networkName=vms \
  -D evictionStrategy=LiveMigrateIfPossible \
  -D terminationGracePeriod=120 \
  --format yaml | yq eval -P '.items[]' - | awk 'BEGIN{doc=""} /^apiVersion: /{if(doc!=""){print "---";} doc=1} {print}'
```
