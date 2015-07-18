#!/bin/sh

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

change_tree()
{
	find $1 -type f | while read tf ; do
		echo "Resizing $tf"
		dd if=/dev/urandom count=50 2>/dev/null >>$tf || fatal "Can't append $tf"
	done
}
