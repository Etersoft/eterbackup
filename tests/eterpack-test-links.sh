#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_tree $BASEDIR/sample

cd $BASEDIR || exit 1

rm -rf sample-links
mkdir sample-links
for i in $(find -L sample -maxdepth 1 -mindepth 1 -type d) ; do
    ln -s ../$i sample-links/links-$(basename $i)
done

sh -x $ETERPACK update --followlinks sample-links packed || exit 1

$ETERPACK check packed || fatal "check failed"

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
