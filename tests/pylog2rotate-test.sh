#!/bin/sh

# test log2rotate from pylog2rotate package

BASEDIR=/tmp/eterbackup-LOG2R

rm -rf $BASEDIR
mkdir -p "$BASEDIR"


cd "$BASEDIR" || exit

mkdir -p backup && cd backup || exit
echo "backup-2015-07-??"
for i in $(seq 11 31) ; do
        touch "backup-2015-07-$i"
done

echo "KEEP:"
ls -1 | sort -r | log2rotate --keep --format "backup-%Y-%m-%d"
echo
echo "DELETE:"
ls -1 | sort -r | log2rotate --delete --format "backup-%Y-%m-%d"
cd -


exit

# CHECK ME: works only for dates
mkdir -p back && cd back || exit
echo
echo "back-??"
for i in $(seq 11 91) ; do
        touch "back-$i"
done

#ls -1 | sort
#echo
ls -1 | sort | log2rotate --keep --format "back-%f"
cd -


mkdir -p long && cd long || exit
echo
echo "long-??.tar.null"
for i in $(seq 11 91) ; do
        touch "long-$i.tar.null"
done

#ls -1 | sort
#echo
ls -1 | sort | log2rotate --keep --format "long-%f.tar.null"
cd -
