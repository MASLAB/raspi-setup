#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <username> <userpass>"
  exit 1
fi

MASLAB_TEAM_NAME="$1"
MASLAB_TEAM_PASS="$2"

# read -p "Team name (ex: team0): " MASLAB_TEAM_NAME
# read -sp "Team password: " MASLAB_TEAM_PASS

if [[ "$MASLAB_TEAM_NAME" =~ [^a-z0-9] ]] ; then
  echo "Error: Only lowercase and number allowed in team name. No whitespace. (ex: team0)" >&2; exit 1
fi

source ./utils/const.sh

source ./utils/echo-color.sh

if ! [[ -f "$BASE_IMAGE_XZ_PATH" ]]; then
  echo "Base image not found. Running base image setup script"
  ./setup-base.sh
fi

# Constant
TEAM_IMAGE_DIR=./team-image
TEAM_IMAGE_NAME=maslab-team
TEAM_IMAGE_PATH=$TEAM_IMAGE_DIR/$TEAM_IMAGE_NAME.img

if ! [[ -f "$TEAM_IMAGE_PATH" ]]; then
  # Make folder
  echo_color $ECHO_BLUE "Making folder to store team image"
  mkdir -p $TEAM_IMAGE_DIR
  
  # Extract base compressed image
  echo_color $ECHO_BLUE "Extracting base maslab image"
  xz -dkv $BASE_IMAGE_XZ_PATH

  # Move base compressed image
  echo_color $ECHO_BLUE "Move compressed image to team image folder"
  mv -v $BASE_IMAGE_PATH $TEAM_IMAGE_PATH
fi

# Mount image
echo_color $ECHO_BLUE "Mounting base image"
MOUNT_POINT=/mnt/$BASE_IMAGE_NAME
export MOUNT_POINT

source ./utils/mount-image.sh

mount_image "$TEAM_IMAGE_PATH" "$MOUNT_POINT"

# Customize image
echo_color $ECHO_BLUE "Customizing image for $MASLAB_TEAM_NAME"

## Set config files
echo_color $ECHO_PURPLE "Generate and set cloud-init file"
TEAM_CONFIGS=( $(./utils/generate-config.sh $MASLAB_TEAM_NAME $MASLAB_TEAM_PASS) )
cp ${TEAM_CONFIGS[0]} $MOUNT_POINT/boot/user-data
cp ${TEAM_CONFIGS[1]} $MOUNT_POINT/boot/network-config

# Unmount image
echo_color $ECHO_BLUE "Unmounting maslab image"
unmount_image

# Write image
SD_CARD_DEV=/dev/$(lsblk | grep -oh -E -i -w 'sd[a-z]+')
echo_color $ECHO_BLUE "Writing to $SD_CARD_DEV"
rpi-imager --cli $TEAM_IMAGE_PATH $SD_CARD_DEV