#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <username> <userpass>"
  exit 1
fi

USER="$1"
PASSWORD="$2"
CONFIG_DIR="./team-configs"
CLOUD_INIT_CONFIG_FILE="$CONFIG_DIR/cloud-init-${USER}.cfg"
NETPLAN_CONFIG_FILE="$CONFIG_DIR/network-${USER}.yaml"

## Automatically generate keys
# KEYDIR="./team-keys"
# KEYFILE="$KEYDIR/id_ed25519_${USER}"

# mkdir -p "$CONFIG_DIR" "$KEYDIR"

# if [[ ! -f "$KEYFILE" ]]; then
#   ssh-keygen -t ed25519 -C "$USER@pi" -N "" -f "$KEYFILE"
# fi

# PUB_KEY="$(cat "$KEYFILE.pub")"
# PRV_KEY="$(cat "$KEYFILE")"

PASS_HASH="$(openssl passwd -6 $PASSWORD)" # Hash it cus why not
WIFI_PASS_HASH="$(openssl passwd -6 ${PASSWORD}wifi)" # Hash it cus why not

cat > "$CLOUD_INIT_CONFIG_FILE" <<EOF
#cloud-config
hostname: ${USER}pi
manage_etc_hosts: true
packages:
- avahi-daemon
apt:
  conf: |
    Acquire {
      Check-Date "false";
    };
timezone: America/New_York
keyboard:
  model: pc105
  layout: "us"
enable_ssh: true
users:
  - name: $USER
    groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "$PASS_HASH"
ssh_pwauth: true
EOF

cat > "$NETPLAN_CONFIG_FILE" <<EOF
network:
  version: 2
  wifis:
    renderer: NetworkManager
    wlan0:
      dhcp4: true
      regulatory-domain: "US"
      access-points:
        "${USER}wifi":
          password: "$WIFI_PASS_HASH"
          mode: ap
      optional: true
EOF

# echo "Cloud-init config: $CLOUD_INIT_CONFIG_FILE"
# echo "SSH private key: $KEYFILE"
# echo "SSH public key: $KEYFILE.pub"

echo $CLOUD_INIT_CONFIG_FILE $NETPLAN_CONFIG_FILE
