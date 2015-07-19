#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

cd $BASEDIR || exit 1

sh -x $ETERPACK update --depth 0 sample packed || fatal "Error in update"

$ETERPACK extract packed unpacked || fatal "Error in extract"

diff_dirs unpacked sample

diffls_dirs unpacked sample

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
