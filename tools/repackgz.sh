#!/bin/sh

# repack sql.gz with zpaq

for i in $@ ; do
    echo $i
    bn=$(basename $i .sql)
    gunzip -c $i >$bn || exit
    zpaq a "ppp.???.zpaq" $bn || exit
    rm -f $bn
done
