#!/usr/bin/env bash

# Echo colors
ECHO_BLACK='\033[1;30m'
ECHO_RED='\033[1;31m'
ECHO_GREEN='\033[1;32m'
ECHO_ORANGE='\033[1;33m'
ECHO_BLUE='\033[1;34m'
ECHO_PURPLE='\033[1;35m'
ECHO_CYAN='\033[1;36m'
ECHO_GRAY='\033[1;37m'
ECHO_CLEAR='\033[0m' # No Color

echo_color() {
    echo -e "$1$2$ECHO_CLEAR"
}