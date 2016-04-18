#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

mkdir -p $BASEDIR/sample/stage0

cd $BASEDIR || exit 1

$ETERPACK update sample packed || exit 1

$ETERPACK extract packed unpacked || fatal "Error in extract"

diff_dirs unpacked sample

diffls_dirs unpacked sample

$ETERPACK check packed || fatal "check failed"

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
