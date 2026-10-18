#!/bin/sh

# http://mywiki.wooledge.org/Bashism
# https://wiki.ubuntu.com/DashAsBinSh

EXCL=-eSC2086,SC2039,SC3043,SC2034,SC2068,SC2155

# style and info only
EXCL="$EXCL,SC2001,SC2004,SC2012,SC2317"

if [ -n "$1" ] ; then
    shellcheck $EXCL "$1"
    exit
fi

# eterpack and eterattrstore are bash scripts
checkbashisms -f $(grep -l '^#!/bin/sh' bin/*)

shellcheck $EXCL \
	bin/*
