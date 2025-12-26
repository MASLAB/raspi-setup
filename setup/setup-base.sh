#!/usr/bin/env bash

source ./utils/echo-color.sh

# Make folder
echo_color $ECHO_BLUE "Making folder to store image"
mkdir -p ./base-image

# Constants
BASE_IMAGE_DIR=./base-image
BASE_IMAGE_PATH=$BASE_IMAGE_DIR/raspios.img
BASE_IMAGE_XZ_PATH=$BASE_IMAGE_PATH.xz

# Download base image
echo_color $ECHO_BLUE "Downloading base image from Raspberry Pi"
if ! [[ -f "$BASE_IMAGE_XZ_PATH" ]]; then
    wget -nc -O $BASE_IMAGE_XZ_PATH http://downloads.raspberrypi.org/raspios_arm64_latest
else
    echo -e "Image is already downloaded"
fi

# Extract image
echo_color $ECHO_BLUE "Extracting base image"
if ! [[ -f "$BASE_IMAGE_PATH" ]]; then
    xz -dkv $BASE_IMAGE_XZ_PATH
else
    echo -e "Image is already extracted"
fi

# Mount image
echo_color $ECHO_BLUE "Mounting base image"
MOUNT_POINT=/mnt/raspios
export MOUNT_POINT

source ./utils/mount-image.sh

if ! mountpoint -q "$MOUNT_POINT"; then
    mount_image "$BASE_IMAGE_PATH" "$MOUNT_POINT"
else
    echo "Image is already mounted"
fi

# Customize image
echo_color $ECHO_BLUE "Customizing image for MASLAB"

source ./utils/run-chroot.sh

echo_color $ECHO_GRAY "Update"
run-chroot << EOF
apt update
apt -y dist-upgrade --auto-remove --purge
apt clean
EOF

echo_color $ECHO_BLUE "Unmounting modified image"
unmount_image


