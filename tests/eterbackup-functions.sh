#!/bin/sh

fatal()
{
	echo "$*"
	exit 1
}

GROUP=remotelogin

create_files()
{
	local td="$1"
	echo "Creating test data in dir $td ..."

	for f in $(seq 1 10) ; do
		tf=$(mktemp $td/tf-XXXX)
		dd if=/dev/urandom of=$tf count=100 2>/dev/null || fatal "Can't create $tf"
		chgrp $GROUP $tf
	done

	for f in $(seq 1 5) ; do
		tf=$(mktemp $td/.tf-XXXX)
		dd if=/dev/urandom of=$tf count=100 2>/dev/null || fatal "Can't create $tf"
	done

	tf1=$(mktemp $td/.tfZ-XXXX)
	tf2=$(mktemp -u $td/.tfL-XXXX)
	tf3=$(mktemp -u $td/.tfL-XXXX)
	tf4=$(mktemp -u $td/.tfL-XXXX)
	# link to exists file
	ln -s $tf1 $tf2
	# link to unexists file
	ln -s $tf3 $tf4
}

create_tree()
{
	local TESTDIR="$1"
	mkdir -p $TESTDIR || exit
	for i in $(seq 1 10) ; do
		td=$(mktemp -d $TESTDIR/td-XXXX)
		chgrp $GROUP $td
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

diff_dirs()
{
	echo
	echo "Diffing $2:"
	diff -r --no-dereference $1 $2 || fatal "Failed"
}
