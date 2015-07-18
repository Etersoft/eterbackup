#!/bin/sh

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

fatal()
{
	echo "$*"
	exit 1
}

create_files()
{
	local td="$1"
	echo "Creating test data in dir $td..."
	for f in $(seq 1 20) ; do
		tf=$(mktemp $td/tf-XXXX)
		dd if=/dev/urandom of=$tf count=100 2>/dev/null || fatal "Can't create $tf"
	done
}

create_tree()
{
	local TESTDIR="$1"
	mkdir -p $TESTDIR || exit
	for i in $(seq 1 10) ; do
		td=$(mktemp -d $TESTDIR/td-XXXX)
		create_files $td
	done

	create_files $TESTDIR
}

create_tree $BASEDIR/sample

#mkdir -p $BASEDIR || exit
cd $BASEDIR || exit 1

$ETERPACK update sample packed || exit 1

$ETERPACK extract packed unpacked || exit 1

echo
echo "Diffing:"
diff -r unpacked sample || exit 1

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
#rm -rf $BASEDIR
