#!/bin/bash

team="$(hostname)"
ip="$(hostname -I | grep -oh -E -i -w '\b((10)|(18))[^ ]+')"
ssid="$(iw dev wlan0 info | grep ssid | awk '{print $2}')"
curl "http://maslab.mit.edu/pollmemaybe/?team=${team}&ip=${ip}&ssid=${ssid}">/dev/null