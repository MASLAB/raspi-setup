#!/usr/bin/env bash

run-chroot() {
    capsh "--drop=cap_setfcap" "--chroot=${MOUNT_POINT}/" -- -e "$@"
}