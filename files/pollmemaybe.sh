#!/bin/bash

team="$(hostname)"
ip="$(hostname -I | grep -oh -E -i -w '\b((10)|(18))[^ ]+')"
curl "http://maslab.mit.edu/pollmemaybe/?team=${team}&ip=${ip}">/dev/null