#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

cd $BASEDIR || exit 1

$ETERPACK update --depth 0 --exclude /stage1 sample packed || fatal "Error in update"

$ETERPACK extract packed unpacked || fatal "Error in extract"

[ -d unpacked/stage1 ] && fatal "excluded stage1 dir is exists"

cp -al sample sample-mod
rm -rf sample-mod/stage1

$ETERPACK compare packed sample-mod || fatal "comparison is failed"

diff_dirs unpacked sample-mod

diffls_dirs unpacked sample-mod



echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
