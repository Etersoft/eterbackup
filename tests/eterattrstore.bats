#!/usr/bin/env bats
# eterattrstore and saving of attributes and special files by eterpack

setup()
{
	load test_helper
	require_cmd metastore pax
	common_setup
}

create_special_tree()
{
	mkdir -p sample/dir
	echo data >sample/dir/file
	echo exec >sample/dir/script
	chmod 0750 sample/dir/script
	chmod 0700 sample/dir
	chgrp "$TEST_GROUP" sample/dir/file
	mkfifo sample/dir/fifo
	ln -s file sample/dir/link
	ln -s nonexistent sample/dir/broken-link
	echo root >sample/rootfile
	chmod 0604 sample/rootfile
	ln -s dir/file sample/rootlink
}

@test "save, metafiles, clear" {
	create_special_tree
	cd sample
	"$ETERATTRSTORE" save
	[ -s .metadata ]
	[ -s .eterpack.special.files.pax ]
	run -0 "$ETERATTRSTORE" metafiles
	[ "${lines[*]}" = ".eterpack.special.files.pax .metadata" ]
	"$ETERATTRSTORE" clear
	[ ! -e .metadata ]
	[ ! -e .eterpack.special.files.pax ]
}

@test "restore special files and attributes" {
	create_special_tree
	(cd sample && "$ETERATTRSTORE" save)
	mkdir restored
	cp -a sample/.metadata sample/.eterpack.special.files.pax restored/
	mkdir restored/dir
	echo data >restored/dir/file
	echo exec >restored/dir/script
	echo root >restored/rootfile
	touch -r sample/dir/file restored/dir/file
	touch -r sample/dir/script restored/dir/script
	touch -r sample/rootfile restored/rootfile
	(cd restored && "$ETERATTRSTORE" restore && "$ETERATTRSTORE" clear)
	(cd sample && "$ETERATTRSTORE" clear)
	assert_same_tree sample restored
}

@test "eterpack keeps attributes and special files" {
	require_zpaq
	create_special_tree
	"$ETERPACK" update sample packed
	# metafiles are removed from the source after packing
	[ ! -e sample/.metadata ]
	"$ETERPACK" extract packed unpacked
	[ ! -e unpacked/.metadata ]
	assert_same_tree sample unpacked
}

@test "eterpack keeps attributes with --depth 0" {
	require_zpaq
	create_special_tree
	"$ETERPACK" update --depth 0 sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "eterpack --noattribute skips special files" {
	require_zpaq
	create_special_tree
	"$ETERPACK" update --noattribute sample packed
	"$ETERPACK" extract --noattribute packed unpacked
	[ -f unpacked/dir/file ]
	[ ! -e unpacked/dir/fifo ]
	[ ! -L unpacked/dir/link ]
}

@test "unknown command fails" {
	run ! "$ETERATTRSTORE" foo
	run -0 "$ETERATTRSTORE" --help
}
