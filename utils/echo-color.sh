#!/usr/bin/env bash

# Echo colors
ECHO_BLUE='\033[0;34m'
ECHO_GRAY='\033[0;37m'
ECHO_CLEAR='\033[0m' # No Color

echo_color() {
    echo -e "$1$2$ECHO_CLEAR"
}