#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample1
create_tree $BASEDIR/sample2

cd $BASEDIR || exit 1

mkdir sample3
#mkdir sample3-test
cp -a sample1/* sample2/* sample3/ || fatal
#cp -af sample2/* sample3/* sample3-test/ || fatal
cp -a sample1 sample4 || fatal

# twice
$ETERPACK update sample1 packed1 || exit 1
$ETERPACK update sample1 packed1 || exit 1

$ETERPACK update sample2 packed2 || exit 1

# TODO: we use other dir for update (2 and next 3): we lost prev. metainfo here
$ETERPACK update sample2 packed3 || exit 1
$ETERPACK update sample3 packed3 || exit 1

# change and pack
$ETERPACK update sample4 packed4 || exit 1
change_tree sample4
# twice
$ETERPACK update sample4 packed4 || exit 1
$ETERPACK update sample4 packed4 || exit 1

for i in 1 2 3 4; do
	$ETERPACK extract packed$i unpacked$i || exit 1
done

# hack
#mv sample3 sample3-old
#mv sample3-test sample3

for i in 1 2 3 4; do
	diff_dirs unpacked$i sample$i
done

#$ETERPACK compare packed sample || exit 1

echo "Done! OK!"

echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
