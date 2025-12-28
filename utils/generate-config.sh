#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <username> <userpass>"
  exit 1
fi

source ./utils/const.sh

USER="$1"
PASSWORD="$2"
CONFIG_DIR=$WORKING_DIR/team-configs
CLOUD_INIT_CONFIG_FILE="$CONFIG_DIR/cloud-init-${USER}.cfg"
NETPLAN_CONFIG_FILE="$CONFIG_DIR/network-${USER}.yaml"

mkdir -p "$CONFIG_DIR"

## Automatically generate keys
# KEYDIR="./team-keys"
# KEYFILE="$KEYDIR/id_ed25519_${USER}"

# mkdir -p "$KEYDIR"

# if [[ ! -f "$KEYFILE" ]]; then
#   ssh-keygen -t ed25519 -C "$USER@pi" -N "" -f "$KEYFILE"
# fi

# PUB_KEY="$(cat "$KEYFILE.pub")"
# PRV_KEY="$(cat "$KEYFILE")"

PASS_HASH="$(openssl passwd -6 $PASSWORD)" # Hash it cus why not
WIFI_SSID=${USER}wifi
WIFI_PASS=${PASSWORD}wifi
WIFI_PASS_PSK="$(wpa_passphrase $WIFI_SSID $WIFI_PASS | grep -oP '\bpsk=\K([a-f0-9]{64})')"

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
runcmd:
  - sudo raspi-config nonint do_i2c 0
  - sudo raspi-config nonint do_spi 0
  - sudo raspi-config nonint do_serial_hw 0
  - sudo raspi-config nonint do_serial_cons 1
  - sudo raspi-config nonint do_ssh 0
  - sudo raspi-config nonint do_camera 0
  - sudo raspi-config nonint disable_raspi_config_at_boot 0
  - sudo raspi-config nonint do_boot_behaviour B1
  - sudo rpi-eeprom-config --apply /eeprom.conf
  - sudo reboot
EOF

cat > "$NETPLAN_CONFIG_FILE" <<EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:
      dhcp4: true
      optional: true
  wifis:
    hotspot:
      match:
        name: wlan0
      dhcp4: true
      optional: false
      regulatory-domain: US
      access-points:
        "${USER}wifi":
          password: $WIFI_PASS_PSK
          mode: ap
EOF

echo "$USER,$PASSWORD" >> $WORKING_DIR/password.txt

# echo "Cloud-init config: $CLOUD_INIT_CONFIG_FILE"
# echo "SSH private key: $KEYFILE"
# echo "SSH public key: $KEYFILE.pub"

echo $CLOUD_INIT_CONFIG_FILE $NETPLAN_CONFIG_FILE
