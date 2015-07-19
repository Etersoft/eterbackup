#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

cd $BASEDIR || exit 1

$ETERPACK update sample1 packed && fatal "update with unexists dir!"

#$ETERPACK update sample packed || fatal "can't pack sapmle"

$ETERPACK extract packed1 unpacked && fatal "extract from unexists dir!"

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
