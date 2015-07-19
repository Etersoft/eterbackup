#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

for i in d1 d2 d3 ; do
	create_tree $BASEDIR/sample/$i
done

cd $BASEDIR || exit 1

$ETERPACK update --depth 2 sample packed || exit 1

$ETERPACK extract packed unpacked || exit 1

$ETERPACK compare packed unpacked || exit 1

echo
echo "Diffing:"
diff -r unpacked sample || exit 1

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
