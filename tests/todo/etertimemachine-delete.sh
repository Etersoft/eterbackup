#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack
ETERTM=$(pwd)/../bin/etertimemachine

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

cd $BASEDIR || exit 1

$ETERTM update sample timemachine || exit 1
$ETERTM update sample timemachine || exit 1
$ETERTM update sample timemachine && fatal "Failed rotate for exists prev dir"

sh -x $ETERTM delete --force --thinner log2 timemachine || exit 1

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
rm -rf $BASEDIR
