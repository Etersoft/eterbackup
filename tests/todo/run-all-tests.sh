#!/bin/sh
for i in *.sh ; do
	[ "$i" = $(basename $0) ] && continue
	[ "$i" = "eterbackup-functions.sh" ] && continue
	./$i >/dev/null 2>/dev/null && echo "$i is successful" || echo "$i is FAILED"
done
