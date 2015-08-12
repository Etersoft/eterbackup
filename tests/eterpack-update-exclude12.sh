#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

cd $BASEDIR || exit 1

sh -x $ETERPACK update --depth 1 --exclude stage1/stage2 sample packed || fatal "update failed"

$ETERPACK extract packed unpacked || fatal "extract failed"

[ -d unpacked/stage1 ] || fatal "missed stage1 dir"

[ -d unpacked/stage1/stage2 ] || fatal "broken excluded stage1/stage2 dir is not exists"



echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
