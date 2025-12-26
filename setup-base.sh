#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

source ./utils/const.sh

source ./utils/echo-color.sh

# Make folder
echo_color $ECHO_BLUE "Making folder to store base image"
mkdir -p $BASE_IMAGE_DIR

# Download base image
echo_color $ECHO_BLUE "Downloading latest raspios image from Raspberry Pi"
if ! [[ -f "$RASPIOS_IMAGE_XZ_PATH" ]]; then
    wget -nc -O $RASPIOS_IMAGE_XZ_PATH http://downloads.raspberrypi.org/raspios_arm64_latest
else
    echo -e "Image is already downloaded"
fi

# Copy compressed image
echo_color $ECHO_BLUE "Extracting base image"
xz -dkv $RASPIOS_IMAGE_XZ_PATH

# Mount image
echo_color $ECHO_BLUE "Mounting base image"
MOUNT_POINT=/mnt/$RASPIOS_IMAGE_NAME
export MOUNT_POINT

source ./utils/mount-image.sh

mount_image "$RASPIOS_IMAGE_PATH" "$MOUNT_POINT"

# Customize image
echo_color $ECHO_BLUE "Customizing image for MASLAB"

source ./utils/run-chroot.sh

echo_color $ECHO_PURPLE "Update"
run-chroot << EOF
apt update
apt -y dist-upgrade --auto-remove --purge
apt clean
EOF

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

echo_color $ECHO_PURPLE "Install XRDP"
run-chroot << EOF
apt install -y xrdp
EOF

echo_color $ECHO_PURPLE "Override boot files"
install -m 644 files/cmdline.txt "${MOUNT_POINT}/boot/"
install -m 644 files/config.txt "${MOUNT_POINT}/boot/"

echo_color $ECHO_BLUE "Unmounting maslab image"
unmount_image

echo_color $ECHO_BLUE "Compressing maslab image"
xz -v --compress --force --threads 0 --memlimit-compress=50% -6 \
	--stdout "$RASPIOS_IMAGE_PATH" > "$BASE_IMAGE_XZ_PATH"


