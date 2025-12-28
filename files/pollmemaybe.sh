#!/bin/bash

team="$(hostname)"
ip="$(nmcli device show wlan1 | grep IP4.ADDRESS | grep -oh -E -i -w "([0-9]{1,3}[\.]){3}[0-9]{1,3}")" # https://www.shellhacks.com/regex-find-ip-addresses-file-grep/
ssid="$(nmcli device show wlan1 | grep GENERAL.CONNECTION | awk '{print $2}')"
curl "http://maslab.mit.edu/pollmemaybe/?team=${team}&ip=${ip}&ssid=${ssid}">/dev/null