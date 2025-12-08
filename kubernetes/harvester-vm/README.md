# HARVESTER-VM

## PVC

```bash
kcl run main.k \
  -D enablePvc=true \
  -D name=dev2-disk-0 \
  -D namespace=default \
  -D imageNamespace=default \
  -D imageId=image-t9w92 \
  -D storage=10Gi \
  -D storageClass=longhorn \
  -D volumeMode=Block \
  -D 'accessModes=["ReadWriteMany"]'
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
  -D enablePvc=false \
  -D enableCloudConfig=true \
  -D userdata=${CLOUDCFG_B64}
```
