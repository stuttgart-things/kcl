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
