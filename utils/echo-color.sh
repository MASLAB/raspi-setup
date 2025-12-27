#!/usr/bin/env bash

# Echo colors
ECHO_BLUE='\033[1;34m'
ECHO_PURPLE='\033[1;35m'
ECHO_GRAY='\033[1;37m'
ECHO_CLEAR='\033[0m' # No Color

echo_color() {
    echo -e "$1$2$ECHO_CLEAR"
}