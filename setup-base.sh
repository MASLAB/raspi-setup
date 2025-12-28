#!/usr/bin/env bash
set -eEo pipefail

source ./utils/const.sh

# Start fresh if clean
while [ "$1" != "" ]; do
  case $1 in
  --clean)
    rm -f $RASPIOS_IMAGE_PATH $RASPIOS_IMAGE_XZ_PATH $BASE_IMAGE_PATH
    ;;
  *)
    ;;
  esac
  shift
done

source ./utils/echo-color.sh

# Make folder
echo_color $ECHO_BLUE "Making folder to store base image"
mkdir -p $WORKING_DIR

# Download base image
echo_color $ECHO_BLUE "Downloading latest raspios image from Raspberry Pi"
if ! [[ -f "$RASPIOS_IMAGE_XZ_PATH" ]]; then
  wget -nc -O $RASPIOS_IMAGE_XZ_PATH http://downloads.raspberrypi.org/raspios_arm64_latest
else
  echo_color $ECHO_GREEN "Image is already downloaded"
fi

# Extract compressed image
echo_color $ECHO_BLUE "Extracting raspios image"
if ! [[ -f "$RASPIOS_IMAGE_PATH" ]]; then
  xz -dkv $RASPIOS_IMAGE_XZ_PATH
else
  echo_color $ECHO_GREEN "Image is already extracted"
fi

# Mount image
echo_color $ECHO_BLUE "Mounting raspios image"
MOUNT_POINT=/mnt/$RASPIOS_IMAGE_NAME
export MOUNT_POINT

source ./utils/mount-image.sh

mount_image "$RASPIOS_IMAGE_PATH" "$MOUNT_POINT"
cleanup() {
  echo_color $ECHO_RED "Error/Interrupted while image is mounted"
  unmount_image
  exit 1
}
trap cleanup ERR SIGINT # Trap to unmount and exit right after

# Customize image
echo_color $ECHO_BLUE "Customizing image for MASLAB"

source ./utils/run-chroot.sh

## Update
echo_color $ECHO_PURPLE "Update software"
run-chroot << EOF
apt update
apt -y dist-upgrade --auto-remove --purge
apt clean
EOF
## USB WiFi Driver
echo_color $ECHO_PURPLE "Install USB WiFi driver"
run-chroot << EOF
apt install -y dkms build-essential
git clone https://github.com/lwfinger/rtw88
cd rtw88
dkms install /rtw88
make install_fw
cp rtw88.conf /etc/modprobe.d/
cd /
rm -rf /rtw88
sleep 5
EOF
## XRDP
echo_color $ECHO_PURPLE "Install XRDP"
run-chroot << EOF
apt install -y xrdp
EOF
## MASLAB Update
echo_color $ECHO_PURPLE "Setup maslab-update script"
run-chroot << EOF
apt install -y jq
EOF
sudo install -m 755 files/maslab-update "${MOUNT_POINT}/usr/local/bin"
sudo install -m 644 files/stm32prog.py "${MOUNT_POINT}/usr/local/bin"
## Pollmemaybe
echo_color $ECHO_PURPLE "Setup PollMeMaybe"
sudo install -m 755 files/pollmemaybe.sh "${MOUNT_POINT}/usr/local/bin"
run-chroot << EOF
crontab -l 2> /dev/null | { cat; echo "* * * * * sh /usr/local/bin/pollmemaybe.sh > /dev/null"; } | crontab -
EOF
## Disable first boot wizard
echo_color $ECHO_PURPLE "Disable first boot wizard"
sudo rm -f "${MOUNT_POINT}/etc/xdg/autostart/piwiz.desktop"
## Boot files
echo_color $ECHO_PURPLE "Override boot files"
sudo install -m 644 files/config.txt "${MOUNT_POINT}/boot/"
## EEPROM file
echo_color $ECHO_PURPLE "Copy EEPROM config file"
sudo install -m 644 files/eeprom.conf "${MOUNT_POINT}/"
## Polkit
echo_color $ECHO_PURPLE "Add polkit rules"
sudo install -m 644 files/10-shutdown-reboot.rules "${MOUNT_POINT}/etc/polkit-1/rules.d/"
sudo install -m 644 files/11-system-sources-refresh.rules "${MOUNT_POINT}/etc/polkit-1/rules.d/"
sudo install -m 644 files/12-wifi.rules "${MOUNT_POINT}/etc/polkit-1/rules.d/"

# Unmount image
echo_color $ECHO_BLUE "Unmounting maslab image"
unmount_image
trap - ERR SIGINT # Remove trap

# Rename modified raspios image
echo_color $ECHO_BLUE "Rename base image"
mv $RASPIOS_IMAGE_PATH $BASE_IMAGE_PATH
