#!/usr/bin/env bash
set -eEuo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <username> <userpass>"
  exit 1
fi

MASLAB_TEAM_NAME="$1"
MASLAB_TEAM_PASS="$2"

if [[ "$MASLAB_TEAM_NAME" =~ [^a-z0-9] ]] ; then
  echo "Error: Only lowercase and number allowed in team name. No whitespace. (ex: team0)" >&2; exit 1
fi

source ./utils/const.sh

source ./utils/echo-color.sh

if ! [[ (-f "$BASE_IMAGE_PATH") || (-f "$TEAM_IMAGE_PATH")]]; then
  echo_color $ECHO_ORANGE "Base/Team image not found. Running base image setup script"
  ./setup-base.sh
fi

if ! [[ -f "$TEAM_IMAGE_PATH" ]]; then
  echo_color $ECHO_BLUE "Rename base image to team"
  mv $BASE_IMAGE_PATH $TEAM_IMAGE_PATH
fi

# Mount image
echo_color $ECHO_BLUE "Mounting base image"
MOUNT_POINT=/mnt/$TEAM_IMAGE_NAME
export MOUNT_POINT

source ./utils/mount-image.sh

mount_image "$TEAM_IMAGE_PATH" "$MOUNT_POINT"
cleanup() {
  echo_color $ECHO_RED "Error while image is mounted"
  unmount_image
  exit 1
}
trap cleanup ERR # Trap to unmount and exit right after

# Customize image
echo_color $ECHO_BLUE "Customizing image for $MASLAB_TEAM_NAME"

## Set config files
echo_color $ECHO_PURPLE "Generate and set cloud-init file"
TEAM_CONFIGS=( $(./utils/generate-config.sh $MASLAB_TEAM_NAME $MASLAB_TEAM_PASS) )
sudo cp ${TEAM_CONFIGS[0]} $MOUNT_POINT/boot/user-data
sudo cp ${TEAM_CONFIGS[1]} $MOUNT_POINT/boot/network-config

# Unmount image
echo_color $ECHO_BLUE "Unmounting maslab team image"
unmount_image
trap - ERR # Trap to unmount and exit right after

# Write image
SD_CARD_DEVS=$(lsblk | grep -oh -E -i -w 'sd[a-z]+')
IMAGED=false
for SD_CARD_DEV in $SD_CARD_DEVS
do
  SD_CARD_BLOCK_SIZE=$(cat /sys/block/$SD_CARD_DEV/queue/physical_block_size)
  IMAGE_SIZE=$(du -sh --block=512 $TEAM_IMAGE_PATH | awk '{print $1}')
  if [[ ($(cat /sys/block/$SD_CARD_DEV/removable) == 1) && \
        ($(cat /sys/block/$SD_CARD_DEV/size) > $IMAGE_SIZE) ]]; then
    echo_color $ECHO_BLUE "Writing to $SD_CARD_DEV"
    sudo rpi-imager --cli $TEAM_IMAGE_PATH /dev/$SD_CARD_DEV
    echo_color $ECHO_BLUE "Ejecting $SD_CARD_DEV"
    sudo eject /dev/$SD_CARD_DEV
    IMAGED=true
    break
  fi
done

if [ "$IMAGED" = true ]; then
  echo_color $ECHO_GREEN "Imaged successfully! SD card for $MASLAB_TEAM_NAME is created."
else
  echo_color $ECHO_RED "No SD card imaged. No card installed?"
  exit 1  
fi

