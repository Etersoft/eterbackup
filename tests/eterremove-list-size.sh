#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERREMOVE=$(pwd)/../bin/eterremove

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_datefiles $BASEDIR/sample

cd $BASEDIR || exit 1

#find sample/ -printf "%C+ %s %p\n"
#find sample/ -printf "%A+ %s %p\n"

echo
$ETERREMOVE remove --size 8 files sample
echo
$ETERREMOVE remove --size 8 --notest files sample || exit

ls -l sample/

for i in 1 2 3 4 5 6 ; do
	test -s sample/tf-$i && fatal "tf-$i need to be deleted"
done

for i in 7 8 9 ; do
	test -s sample/tf-$i || fatal "tf-$i need to be exists"
done

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
