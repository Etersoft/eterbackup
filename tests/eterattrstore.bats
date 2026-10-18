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

@test "eterpack keeps long symlinks and special files with long paths" {
	require_zpaq
	local long100 target
	long100="$(printf 'd%.0s' $(seq 1 100))"
	target="$(printf 't%.0s' $(seq 1 150))"
	mkdir -p "sample/dir/$long100/$long100"
	ln -s short sample/dir/short-link
	ln -s "$target" sample/dir/long-link
	ln -s target "sample/dir/$long100/$long100/link-with-long-path"
	mkfifo "sample/dir/$long100/$long100/fifo-with-long-path"
	"$ETERPACK" update sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "eterpack does not write to the source dir" {
	require_zpaq
	create_special_tree
	chmod a-w sample
	"$ETERPACK" update sample packed
	"$ETERPACK" update --depth 0 sample packed0
	chmod u+w sample
	"$ETERPACK" extract packed unpacked
	"$ETERPACK" extract packed0 unpacked0
	assert_same_tree sample unpacked
	assert_same_tree sample unpacked0
	[ -z "$(ls -A packed packed0 | grep -F .eterpack)" ]
	chmod u+w unpacked unpacked0
}

@test "eterpack refuses a source with the reserved metafile names" {
	require_zpaq
	create_special_tree
	local name
	for name in .metadata .eterpack.special.files.pax .eterpack.follow ; do
		touch "sample/$name"
		run ! "$ETERPACK" update sample packed
		[[ "$output" == *"reserved"* ]]
		rm "sample/$name"
	done
	touch sample/.metadata
	"$ETERPACK" update --noattribute sample packed
}

@test "eterpack restores and updates backups made by the old eterpack" {
	require_zpaq
	create_special_tree
	# the old eterpack packed the metadata files from the source root
	(cd sample && "$ETERATTRSTORE" save)
	"$ETERPACK" update --noattribute sample packed
	(cd sample && "$ETERATTRSTORE" clear)
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
	sleep 1
	echo new >sample/rootfile
	"$ETERPACK" update sample packed
	"$ETERPACK" compare packed sample
	"$ETERPACK" extract packed unpacked2
	assert_same_tree sample unpacked2
}

@test "restore special files saved in the old ustar format" {
	mkdir -p sample/dir
	ln -s file sample/dir/link
	mkfifo sample/dir/fifo
	(cd sample && find . -type l -o -type p | sed -e 's|^\./||' | pax -wd -x ustar -f .eterpack.special.files.pax)
	mkdir restored
	cp sample/.eterpack.special.files.pax restored/
	(cd restored && "$ETERATTRSTORE" restore)
	[ -L restored/dir/link ]
	[ -p restored/dir/fifo ]
}

@test "save and restore with --metadir" {
	create_special_tree
	mkdir meta
	(cd sample && "$ETERATTRSTORE" save --metadir "$BATS_TEST_TMPDIR/meta")
	[ ! -e sample/.metadata ]
	[ -s meta/.metadata ]
	[ -s meta/.eterpack.special.files.pax ]
	mkdir restored
	mkdir restored/dir
	echo data >restored/dir/file
	echo exec >restored/dir/script
	echo root >restored/rootfile
	touch -r sample/dir/file restored/dir/file
	touch -r sample/dir/script restored/dir/script
	touch -r sample/rootfile restored/rootfile
	(cd restored && "$ETERATTRSTORE" restore --metadir "$BATS_TEST_TMPDIR/meta")
	"$ETERATTRSTORE" clear --metadir "$BATS_TEST_TMPDIR/meta"
	[ ! -e meta ]
	assert_same_tree sample restored
}

@test "unknown command fails" {
	run ! "$ETERATTRSTORE" foo
	run -0 "$ETERATTRSTORE" --help
}

@test "eterpack compare detects changed owner group, mode and special files" {
	create_special_tree
	"$ETERPACK" update sample packed
	"$ETERPACK" compare packed sample
	"$ETERPACK" extract packed unpacked
	"$ETERPACK" compare packed unpacked

	cp -a sample sample-mode
	chmod 0640 sample-mode/rootfile
	run ! "$ETERPACK" compare packed sample-mode
	[[ "$output" == *"./rootfile:"*"mode"* ]]

	cp -a sample sample-group
	chgrp "$(id -gn)" sample-group/dir/file
	run ! "$ETERPACK" compare packed sample-group
	[[ "$output" == *"./dir/file:"*"group"* ]]

	cp -a sample sample-link
	ln -sfn other sample-link/dir/link
	run ! "$ETERPACK" compare packed sample-link
	[[ "$output" == *"Special files differ"* ]]
	[[ "$output" == *"+ "*"dir/link => other"* ]]

	cp -a sample sample-fifo
	rm sample-fifo/dir/fifo
	run ! "$ETERPACK" compare packed sample-fifo
	[[ "$output" == *"- "*"dir/fifo"* ]]

	# the attributes are not compared with --noattribute (zpaq compares the mode itself)
	"$ETERPACK" compare --noattribute packed sample-group
}

@test "eterpack compare with --depth 0 and --followlinks checks the attributes" {
	create_special_tree
	"$ETERPACK" update --depth 0 sample packed0
	"$ETERPACK" compare packed0 sample
	chmod 0640 sample/rootfile
	run ! "$ETERPACK" compare packed0 sample

	mkdir -p real/linked
	echo data >real/linked/file
	chgrp "$TEST_GROUP" real/linked/file
	ln -s file real/linked/link
	mkdir src
	ln -s ../real/linked src/linked
	"$ETERPACK" update --followlinks src packedl
	"$ETERPACK" compare packedl src
	"$ETERPACK" extract packedl unpackedl
	"$ETERPACK" compare packedl unpackedl
	chgrp "$(id -gn)" real/linked/file
	run ! "$ETERPACK" compare packedl src
	[[ "$output" == *"./linked/file:"*"group"* ]]
}

@test "special files in excluded dirs are not saved" {
	create_special_tree
	mkdir -p sample/skipped sample/dir/skipped
	ln -s ../dir/file sample/skipped/link
	mkfifo sample/dir/skipped/fifo
	"$ETERPACK" update --exclude /skipped --exclude /dir/skipped sample packed
	"$ETERPACK" extract packed unpacked
	[ ! -e unpacked/skipped ]
	[ ! -e unpacked/dir/skipped ]
	"$ETERPACK" compare --exclude /skipped --exclude /dir/skipped packed sample
	"$ETERPACK" compare packed unpacked
	# by name at the packing depth
	"$ETERPACK" update --exclude skipped sample packedn
	"$ETERPACK" extract packedn unpackedn
	[ ! -e unpackedn/skipped ]
	[ -p unpackedn/dir/skipped/fifo ]
}
