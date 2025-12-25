#!/usr/bin/env bash
set -euo pipefail

IMAGE=""
MNT=""
LOOP=""

mount_image() {
  IMAGE="$1"
  MNT="$2"

  if [[ ! -f "$IMAGE" ]]; then
    echo "Image not found: $IMAGE" >&2
    return 1
  fi

  sudo mkdir -p "$MNT"

  echo "Attaching image..."
  LOOP=$(sudo losetup -fP --show "$IMAGE")
  echo "Loop device: $LOOP"

  ROOT_PART="${LOOP}p2"
  BOOT_PART="${LOOP}p1"

  echo "Mounting root filesystem..."
  sudo mount "$ROOT_PART" "$MNT"

  if lsblk "$BOOT_PART" &>/dev/null; then
    sudo mkdir -p "$MNT/boot"
    sudo mount "$BOOT_PART" "$MNT/boot"
  fi
}

unmount_image() {
  set +e

  if mountpoint -q "$MNT"; then
    sudo umount -R "$MNT"
  fi

  if [[ -n "${LOOP:-}" ]]; then
    sudo losetup -d "$LOOP"
  fi
}
