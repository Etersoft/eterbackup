#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERREMOVE=$(pwd)/../bin/eterremove

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

cd $BASEDIR || exit 1

$ETERREMOVE remove --days 1 --notest dirs sample || exit

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
