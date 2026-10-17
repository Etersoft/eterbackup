# Common helpers for eterbackup bats tests

bats_require_minimum_version 1.5.0

BINDIR="$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)"
ETERPACK="$BINDIR/eterpack"
ETERREMOVE="$BINDIR/eterremove"
ETERTM="$BINDIR/etertimemachine"
ETERATTRSTORE="$BINDIR/eterattrstore"

# secondary group to check that group ownership is saved and restored
TEST_GROUP="${TEST_GROUP:-$(id -gn)}"

common_setup()
{
	cd "$BATS_TEST_TMPDIR" || return
}

require_cmd()
{
	local cmd
	for cmd in "$@" ; do
		command -v "$cmd" >/dev/null || skip "$cmd is not installed"
	done
}

require_zpaq()
{
	require_cmd zpaq metastore pax
	zpaq | head -n1 | grep -q " v7\.15 " || skip "eterpack needs zpaq 7.15"
}

# mark a test for a known, not yet fixed bug: skipped unless RUN_KNOWN_BUGS is set
known_bug()
{
	[ -n "$RUN_KNOWN_BUGS" ] || skip "known bug: $*"
}

# create files with random contents, hidden files and symlinks in dir $1
create_files()
{
	local td="$1"
	local f tf
	for f in $(seq 1 10) ; do
		tf="$(mktemp "$td/tf-XXXX")"
		dd if=/dev/urandom of="$tf" count=100 2>/dev/null
		chgrp "$TEST_GROUP" "$tf"
		chmod a+rwX "$tf"
	done

	for f in $(seq 1 5) ; do
		tf="$(mktemp "$td/.tf-XXXX")"
		dd if=/dev/urandom of="$tf" count=100 2>/dev/null
	done

	local tf1 tf2 tf3 tf4
	tf1="$(mktemp "$td/.tfZ-XXXX")"
	tf2="$(mktemp -u "$td/.tfL-XXXX")"
	tf3="$(mktemp -u "$td/.tfL-XXXX")"
	tf4="$(mktemp -u "$td/.tfL-XXXX")"
	# link to existing file
	ln -s "$tf1" "$tf2"
	# link to nonexistent file
	ln -s "$tf3" "$tf4"
}

# create a tree with 10 subdirs, files in the root and
# the empty stage* dirs used by the --exclude tests
create_tree()
{
	local testdir="$1"
	local i td
	mkdir -p "$testdir"
	for i in $(seq 1 10) ; do
		td="$(mktemp -d "$testdir/td-XXXX")"
		chgrp "$TEST_GROUP" "$td"
		create_files "$td"
	done

	# never excluded
	mkdir -p "$testdir/stage0"
	mkdir -p "$testdir/stage1/stage2/stage3/stage4/stage5"
	mkdir -p "$testdir/stage1/stage22/stage3/stage4/stage5"

	create_files "$testdir"
}

create_spaces_tree()
{
	local testdir="$1"
	mkdir -p "$testdir/space1 first"
	mkdir -p "$testdir/space1 second"
	touch "$testdir/space1 second/file1"
	touch "$testdir/space1 second/file1 space1"
	touch "$testdir/space1 second/file1 space2"
	touch "$testdir/space1 second/file1 пробел"
	mkdir -p "$testdir/пробел1 second"
	touch "$testdir/пробел1 second/file1 пробел"
	touch "$testdir/file3 пробел"
}

create_symbols_tree()
{
	local testdir="$1"
	mkdir -p "$testdir/space1!fi\"rst"
	mkdir -p "$testdir/space1\$sec'ond"
	touch "$testdir/space1!fi\"rst/file5"
	touch "$testdir/space1\$sec'ond/file1"
	touch "$testdir/space1\$sec'ond/file1 space1"
	touch "$testdir/space1\$sec'ond/file1 пробел"
	mkdir -p "$testdir/\"пробел'1-second"
	touch "$testdir/\"пробел'1-second/file1 пробел"
	touch "$testdir/file3!пробел"
	touch "$testdir/file3\$пр'обе'л"
	touch "$testdir/file3-пр\"об'ел"
	touch "$testdir/file3 -d пр\"об\"ел"
}

# big sparse files tf-1 (9G, oldest) .. tf-9 (1G, newest)
create_datefiles()
{
	local testdir="$1"
	local f tf
	mkdir -p "$testdir"
	for f in $(seq 1 9) ; do
		tf="$testdir/tf-$f"
		truncate -s "$((10-f))G" "$tf"
		touch -d "$((10-f)) days ago" "$tf"
	done
}

# append random data to every file in the tree
change_tree()
{
	local tf
	find "$1" -type f | while read -r tf ; do
		dd if=/dev/urandom count=50 2>/dev/null >>"$tf"
	done
}

# remove empty dirs (repeatedly, so nested empty dirs go too)
prune_empty_dirs()
{
	find "$1" -mindepth 1 -depth -type d -empty -delete
}

# print metadata of every entry: type, mode, owner, group, size, link target
# and mtime in seconds for regular files (zpaq keeps seconds only, dir mtime is not kept)
tree_metadata()
{
	(cd "$1" && find . -mindepth 1 -printf '%P|%y|%M|%u|%g|%s|%l|%T@\n') | \
		awk -F'|' 'BEGIN { OFS="|" } { if ($2 == "f") $8 = int($8) ; else $8 = "" ; if ($2 == "d") $6 = "" ; print }' | \
		LC_ALL=C sort
}

# compare two trees by metadata and by contents of regular files
# (diff -r fails on fifos and devices)
assert_same_tree()
{
	diff -u <(tree_metadata "$1") <(tree_metadata "$2")
	local f
	while IFS= read -r -d '' f ; do
		cmp "$1/$f" "$2/$f"
	done < <(cd "$1" && find . -type f -printf '%P\0')
}

# compare trees ignoring empty dirs (they are lost above the packing depth, a known bug)
assert_same_tree_pruned()
{
	rm -rf "$1-pruned" "$2-pruned"
	cp -a "$1" "$1-pruned"
	cp -a "$2" "$2-pruned"
	prune_empty_dirs "$1-pruned"
	prune_empty_dirs "$2-pruned"
	assert_same_tree "$1-pruned" "$2-pruned"
}

# hard-linked copy of tree $1 as $2 without the paths given relative to the tree root
copy_tree_without()
{
	local src="$1" dst="$2"
	shift 2
	cp -al "$src" "$dst"
	local p
	for p in "$@" ; do
		rm -rf "${dst:?}/$p"
	done
}
