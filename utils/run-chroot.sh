#!/usr/bin/env bash

run-chroot() {
    if ! mount | grep -q "$(realpath "${MOUNT_POINT}"/proc)"; then
		mount -t proc proc "${MOUNT_POINT}/proc"
	fi

	if ! mount | grep -q "$(realpath "${MOUNT_POINT}"/dev)"; then
		mount --bind /dev "${MOUNT_POINT}/dev"
	fi
	
	if ! mount | grep -q "$(realpath "${MOUNT_POINT}"/dev/pts)"; then
		mount --bind /dev/pts "${MOUNT_POINT}/dev/pts"
	fi

	if ! mount | grep -q "$(realpath "${MOUNT_POINT}"/sys)"; then
		mount --bind /sys "${MOUNT_POINT}/sys"
	fi

	if ! mount | grep -q "$(realpath "${MOUNT_POINT}"/run)"; then
		mount -t tmpfs  tmpfs "${MOUNT_POINT}/run"
	fi

	if ! mount | grep -q "$(realpath "${MOUNT_POINT}"/tmp)"; then
		mount -t tmpfs  tmpfs "${MOUNT_POINT}/tmp"
	fi

    capsh "--drop=cap_setfcap" "--chroot=${MOUNT_POINT}/" -- -e "$@"
}