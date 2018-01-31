#!/bin/sh

# http://mywiki.wooledge.org/Bashism
# https://wiki.ubuntu.com/DashAsBinSh

EXCL=-eSC2086,SC2039,SC2034,SC2068,SC2155

# TODO:
# SC2154: pkg_filenames is referenced but not assigned.
# SC2002: Useless cat.
EXCL="$EXCL,SC2154,SC2002"

if [ -n "$1" ] ; then
    shellcheck $EXCL "$1"
    exit
fi

checkbashisms -f bin/*

shellcheck $EXCL \
	bin/*
