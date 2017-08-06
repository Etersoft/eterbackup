#!/bin/sh

fatal()
{
	echo "FATAL: $*"
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
		chmod a+rwX $tf
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

	# never exclude stage0
	mkdir -p $TESTDIR/stage0
	#touch $TESTDIR/stage0/file

	mkdir -p $TESTDIR/stage1/stage2/stage3/stage4/stage5
	mkdir -p $TESTDIR/stage1/stage22/stage3/stage4/stage5

	create_files $TESTDIR
	ls -R -l $TESTDIR
}

create_spaces_tree()
{
	local TESTDIR="$1"
	mkdir -p $TESTDIR || exit
	mkdir -p "$TESTDIR/space1 first"
	mkdir -p "$TESTDIR/space1 second"
	touch "$TESTDIR/space1 second/file1"
	touch "$TESTDIR/space1 second/file1 space1"
	touch "$TESTDIR/space1 second/file1 space2"
	touch "$TESTDIR/space1 second/file1 пробел"
	mkdir -p "$TESTDIR/пробел1 second"
	touch "$TESTDIR/пробел1 second/file1 пробел"
	touch "$TESTDIR/file3 пробел"
	ls -R -l $TESTDIR
}

create_symbols_tree()
{
	local TESTDIR="$1"
	mkdir -p $TESTDIR || exit
	mkdir -p "$TESTDIR/space1!fi\"rst"
	mkdir -p "$TESTDIR/space1\$sec'ond"
	touch "$TESTDIR/space1!fi\"rst'/file5"
	touch "$TESTDIR/space1\$sec'ond/file1"
	touch "$TESTDIR/space1\$sec'ond/file1 space1"
	touch "$TESTDIR/space1\$sec'ond/file1 space2"
	touch "$TESTDIR/space1\$sec'ond/file1 пробел"
	mkdir -p "$TESTDIR/\"пробел'1-second"
	touch "$TESTDIR/\"пробел'1-second/file1 пробел"
	touch "$TESTDIR/file3!пробел"
	touch "$TESTDIR/file3\$пр'обе'л"
	touch "$TESTDIR/file3-пр\"об'ел"
	touch "$TESTDIR/file3 -d пр\"об\"ел"
	ls -R -l $TESTDIR
}


create_datefiles()
{
	local TESTDIR="$1"
	mkdir -p $TESTDIR || exit

	local dt
	for f in $(seq 1 9) ; do
		tf="$TESTDIR/tf-$f"
		truncate -s "$((10-$f))G" $tf || fatal "Can't create $tf"
		touch -d "$dt" $tf
		chgrp $GROUP $tf
		chmod a+rwX $tf
		dt="$dt yesterday"
	done
	ls -R -l -h $TESTDIR
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

diffls_dirs()
{
	echo
	echo "Diffing $2 via ls:"
	for i in $1 $2 ; do
		cd $i || return
		LANG=C ls -l --full-time >../$i.list
		cd -
	done

	diff -u -- $1.list $2.list
}
