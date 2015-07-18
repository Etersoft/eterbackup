#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample1
create_tree $BASEDIR/sample2

cd $BASEDIR || exit 1

mkdir sample3
cp -a sample1/* sample2/* sample3/ || fatal
cp -a sample1 sample4 || fatal

# twice
$ETERPACK update sample1 packed1 || exit 1
$ETERPACK update sample1 packed1 || exit 1

$ETERPACK update sample2 packed2 || exit 1

$ETERPACK update sample2 packed3 || exit 1
$ETERPACK update sample3 packed3 || exit 1

# change and pack
$ETERPACK update sample4 packed4 || exit 1
change_tree sample4
$ETERPACK update sample4 packed4 || exit 1
$ETERPACK update sample4 packed4 || exit 1

for i in 1 2 3 4; do
	$ETERPACK extract packed$i unpacked$i || exit 1
done

for i in 1 2 3 4; do
	echo
	echo "Diffing sample$i:"
	diff -r unpacked$i sample$i || exit 1
	echo "Done! OK!"
done

echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
