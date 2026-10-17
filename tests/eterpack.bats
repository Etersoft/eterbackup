#!/usr/bin/env bats
# eterpack: update, extract, compare, check and status

setup()
{
	load test_helper
	require_zpaq
	common_setup
}

@test "update and check" {
	create_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" check packed
	[ -s packed/root.000000.zpaq ]
	[ -s packed/dirs.list ]
	[ -s packed/files.list ]
}

@test "update and extract restore the same tree" {
	create_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "update and compare" {
	create_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" compare packed sample
	"$ETERPACK" compare --checksum packed sample
}

@test "compare detects changed files" {
	known_bug "compare exits with 0 when files differ"
	create_tree sample
	"$ETERPACK" update sample packed
	change_tree sample
	run ! "$ETERPACK" compare packed sample
}

@test "repeated updates append parts and extract the last state" {
	create_tree sample
	"$ETERPACK" update sample packed
	change_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" update sample packed
	"$ETERPACK" check packed
	[ -s packed/root.000002.zpaq ]
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "update merges trees into the same backup" {
	create_tree sample1
	create_tree sample2
	mkdir sample3
	cp -a sample1/. sample2/. sample3/
	"$ETERPACK" update sample2 packed
	"$ETERPACK" update sample3 packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample3 unpacked
}

@test "extract to an existing dir again" {
	create_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" extract packed unpacked
	rm -rf unpacked
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "--depth 0 packs into one archive" {
	create_tree sample
	"$ETERPACK" update --depth 0 sample packed
	[ "$(find packed -name '*.zpaq' | wc -l)" = 2 ]
	"$ETERPACK" compare packed sample
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "--singlearchive packs all subdirs into the root archive" {
	create_tree sample
	"$ETERPACK" update --singlearchive sample packed
	[ -z "$(find packed -mindepth 1 -type d)" ]
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "--depth 2 packs every second level dir separately" {
	mkdir -p sample/a/b sample/a/c
	echo b >sample/a/b/file
	echo c >sample/a/c/file
	echo a >sample/a/file
	"$ETERPACK" update --depth 2 sample packed
	[ -s packed/a/b/b.000000.zpaq ]
	[ -s packed/a/c/c.000000.zpaq ]
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "--depth 2 with nested trees" {
	create_tree sample
	local d
	for d in d1 d2 d3 ; do
		create_tree "sample/$d"
	done
	"$ETERPACK" update --depth 2 sample packed
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked
	"$ETERPACK" compare packed unpacked
	assert_same_tree_pruned sample unpacked
}

@test "--depth 2 with nested trees and names with spaces" {
	create_spaces_tree sample
	local d
	for d in d1 d2 d3 ; do
		create_tree "sample/$d"
	done
	"$ETERPACK" update --depth 2 sample packed
	"$ETERPACK" extract packed unpacked
	"$ETERPACK" compare packed unpacked
	assert_same_tree_pruned sample unpacked
}

@test "empty dir is packed" {
	mkdir -p sample/stage0
	"$ETERPACK" update sample packed
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "empty dirs above --depth are packed" {
	known_bug "empty dirs above the packing depth are lost"
	mkdir -p sample/stage0 sample/stage1/stage2
	"$ETERPACK" update --depth 2 sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "names with spaces" {
	create_spaces_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "names with spaces, --depth 0" {
	create_spaces_tree sample
	"$ETERPACK" update --depth 0 sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "names with shell special chars" {
	create_symbols_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "--followlinks packs dirs behind symlinks" {
	known_bug "dirs are extracted under the link target names, not the link names"
	create_tree sample
	mkdir sample-links
	local d
	for d in sample/td-* ; do
		ln -s "../$d" "sample-links/links-$(basename "$d")"
	done
	"$ETERPACK" update --followlinks sample-links packed
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked
	for d in sample/td-* ; do
		diff -r --no-dereference "$d" "unpacked/links-$(basename "$d")/$(basename "$d")"
	done
}

@test "--password encrypts the archive" {
	create_tree sample
	"$ETERPACK" update --password secret sample packed
	[ -e packed/.encrypted ]
	run ! zpaq list packed/root.??????.zpaq
	"$ETERPACK" check --password secret packed
	"$ETERPACK" extract --password secret packed unpacked
	assert_same_tree sample unpacked
}

@test "extract fails with a wrong password" {
	known_bug "extract ignores zpaq errors"
	create_tree sample
	"$ETERPACK" update --password secret sample packed
	run ! "$ETERPACK" extract --password wrong packed unpacked
}

@test "check fails for a broken archive" {
	create_tree sample
	"$ETERPACK" update sample packed
	local part
	part="$(ls packed/td-*/td-*.000001.zpaq | head -n1)"
	dd if=/dev/urandom of="$part" bs=1 count=4096 seek=1024 conv=notrunc 2>/dev/null
	run ! "$ETERPACK" check packed
}

@test "--password with spaces" {
	known_bug "password is passed to zpaq unquoted"
	create_tree sample
	"$ETERPACK" update --password "my secret" sample packed
	"$ETERPACK" extract --password "my secret" packed unpacked
	assert_same_tree sample unpacked
}

@test "--rollback restores the previous state" {
	mkdir -p sample/dir
	echo first >sample/dir/file
	echo first >sample/rootfile
	"$ETERPACK" update sample packed
	echo second >sample/dir/file
	echo second >sample/rootfile
	"$ETERPACK" update sample packed
	"$ETERPACK" extract --rollback 1 packed unpacked
	[ "$(cat unpacked/dir/file)" = first ]
	[ "$(cat unpacked/rootfile)" = first ]
}

@test "--execute runs a command after every archive" {
	mkdir -p sample/a sample/b
	echo a >sample/a/file
	echo b >sample/b/file
	echo r >sample/rootfile
	printf '#!/bin/sh\necho "$1" >>%s/executed.list\n' "$BATS_TEST_TMPDIR" >hook.sh
	chmod +x hook.sh
	"$ETERPACK" update --execute "$BATS_TEST_TMPDIR/hook.sh" sample packed
	[ "$(wc -l <executed.list)" = 3 ]
	grep -q '/a/a\.??????\.zpaq$' executed.list
	grep -q '/root\.??????\.zpaq$' executed.list
}

@test "--execute failure stops update" {
	mkdir -p sample/a
	echo a >sample/a/file
	run ! "$ETERPACK" update --execute false sample packed
}

@test "status of a completed backup" {
	create_tree sample
	"$ETERPACK" update sample packed
	[ -s packed/.last-updated ]
	[ ! -e packed/.status ]
	run -0 "$ETERPACK" status packed
	[[ "$output" == *"Archive is completed"* ]]
}

@test "status of an interrupted backup" {
	create_tree sample
	"$ETERPACK" update sample packed
	echo "in progress" >packed/.status
	run -1 "$ETERPACK" status packed
	[[ "$output" == *"incomplete"* ]]
}

@test "inlist prints dirs and root files" {
	create_tree sample
	run -0 "$ETERPACK" inlist sample
	[[ "$output" == *"stage0"* ]]
	[[ "$output" == *"td-"* ]]
}

@test "update fails for a nonexistent source" {
	run ! "$ETERPACK" update nonexistent packed
	[ ! -e packed ]
}

@test "extract fails for a nonexistent backup" {
	run ! "$ETERPACK" extract nonexistent unpacked
}

@test "unknown command fails" {
	run ! "$ETERPACK" foo
	run -0 "$ETERPACK" --help
}
