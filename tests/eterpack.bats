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
	create_tree sample
	"$ETERPACK" update sample packed
	change_tree sample
	run ! "$ETERPACK" compare packed sample
}

@test "compare detects removed and new files" {
	create_tree sample
	"$ETERPACK" update sample packed
	cp -a sample sample-new
	echo new >sample-new/td-new
	echo new >"$(ls -d sample-new/td-* | head -n1)/new"
	run ! "$ETERPACK" compare packed sample-new
	cp -a sample sample-removed
	rm "$(ls sample-removed/td-*/tf-* | head -n1)"
	run ! "$ETERPACK" compare packed sample-removed
	rm "$(ls sample/tf-* | head -n1)"
	run ! "$ETERPACK" compare packed sample
}

@test "compare an extracted backup" {
	create_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" extract packed unpacked
	"$ETERPACK" compare packed unpacked
}

@test "compare with --depth 0, --depth 2 and --singlearchive" {
	create_tree sample
	mkdir -p sample/a/b
	echo f >sample/a/b/f
	echo g >sample/a/g
	"$ETERPACK" update --depth 0 sample packed0
	"$ETERPACK" compare packed0 sample
	"$ETERPACK" update --depth 2 sample packed2
	"$ETERPACK" compare packed2 sample
	"$ETERPACK" update --singlearchive sample packeds
	"$ETERPACK" compare packeds sample
	change_tree sample
	run ! "$ETERPACK" compare packed0 sample
	run ! "$ETERPACK" compare packed2 sample
	run ! "$ETERPACK" compare packeds sample
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

# check_removed "UPDATE OPTIONS": removed files and dirs do not come back on restore
check_removed()
{
	mkdir -p sample/a/sub sample/b/sub sample/c sample/-d
	echo 1 >sample/a/f1
	echo 2 >sample/a/sub/f
	echo 3 >sample/b/sub/f
	echo 4 >sample/c/f
	echo 5 >sample/-d/f
	echo 6 >sample/rootf
	echo 7 >sample/-rootf
	echo 8 >sample/keep
	"$ETERPACK" update $1 sample packed
	rm -r sample/a/f1 sample/a/sub sample/b sample/-d sample/rootf sample/-rootf
	"$ETERPACK" update $1 sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
	"$ETERPACK" compare packed sample
	# the previous state is still there
	# (with --singlearchive every packed dir is a separate version of the archive)
	[ "$1" = --singlearchive ] && return
	"$ETERPACK" extract --rollback 1 packed unpacked1
	[ -f unpacked1/b/sub/f ]
	[ -f unpacked1/-d/f ]
	[ -f unpacked1/rootf ]
}

@test "removed files and dirs are not restored" {
	check_removed
}

@test "removed files and dirs are not restored, --depth 2" {
	check_removed "--depth 2"
}

@test "removed files and dirs are not restored, --singlearchive" {
	check_removed --singlearchive
}

@test "removed files and dirs are not restored, --depth 0" {
	check_removed "--depth 0"
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

@test "--singlearchive with --depth 2 restores dirs in place" {
	mkdir -p sample/a/b sample/c/d
	echo b >sample/a/b/file
	echo d >sample/c/d/file
	echo a >sample/a/file
	"$ETERPACK" update --singlearchive --depth 2 sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
	"$ETERPACK" compare packed sample
}

@test "names starting with a dash" {
	mkdir -p sample/-dir sample/dir
	echo a >sample/-dir/file
	echo b >sample/-rootfile
	echo c >sample/dir/-file
	"$ETERPACK" update sample packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
	"$ETERPACK" update --depth 0 sample packed0
	"$ETERPACK" extract packed0 unpacked0
	assert_same_tree sample unpacked0
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
	assert_same_tree sample unpacked
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
	assert_same_tree sample unpacked
}

@test "empty dir is packed" {
	mkdir -p sample/stage0
	"$ETERPACK" update sample packed
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "empty dirs above --depth are packed" {
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

@test "source and backup paths with spaces" {
	create_tree "my sample"
	"$ETERPACK" update "my sample" "my packed"
	[ -d "my packed/stage0" ]
	"$ETERPACK" check "my packed"
	"$ETERPACK" extract "my packed" "my unpacked"
	assert_same_tree "my sample" "my unpacked"
}

@test "--followlinks packs dirs behind symlinks" {
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
		[ -d "unpacked/links-$(basename "$d")" ] && [ ! -L "unpacked/links-$(basename "$d")" ]
		assert_same_tree "$d" "unpacked/links-$(basename "$d")"
	done
}

@test "--followlinks keeps attributes and special files inside linked dirs" {
	mkdir -p real/dir/sub sample
	echo data >real/dir/file
	chgrp "$TEST_GROUP" real/dir/file
	chmod 0640 real/dir/file
	chmod 0700 real/dir/sub
	mkfifo real/dir/sub/fifo
	ln -s file real/dir/link
	ln -s ../real/dir sample/linked
	echo root >sample/rootfile
	ln -s rootfile sample/rootlink
	"$ETERPACK" update --followlinks sample packed
	"$ETERPACK" extract packed unpacked
	[ ! -L unpacked/linked ]
	assert_same_tree real/dir unpacked/linked
	[ -L unpacked/rootlink ]
	cmp sample/rootfile unpacked/rootfile
}

@test "metafiles of removed links and special files are marked as removed" {
	mkdir -p real/dir sample/dir
	echo data >real/dir/file
	mkfifo sample/dir/fifo
	ln -s ../real/dir sample/linked
	"$ETERPACK" update --followlinks sample packed
	run -0 zpaq list "packed/root.??????.zpaq"
	[[ "$output" == *".eterpack.follow/"* ]]
	[[ "$output" == *".eterpack.special.files.pax"* ]]
	rm sample/linked sample/dir/fifo
	sleep 1
	"$ETERPACK" update --followlinks sample packed
	run -0 zpaq list "packed/root.??????.zpaq"
	[[ "$output" != *".eterpack.follow"* ]]
	[[ "$output" != *".eterpack.special.files.pax"* ]]
	[[ "$output" == *".metadata"* ]]
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "--followlinks with --depth 2 packs root files of linked dirs" {
	create_tree sample
	mkdir sample-links
	ln -s ../sample sample-links/linked
	"$ETERPACK" update --followlinks --depth 2 sample-links packed
	"$ETERPACK" extract packed unpacked
	[ ! -L unpacked/linked ]
	assert_same_tree sample unpacked/linked
}

@test "--password encrypts the archive" {
	create_tree sample
	"$ETERPACK" update --password secret sample packed
	[ -e packed/.encrypted ]
	run ! zpaq list "packed/root.??????.zpaq"
	"$ETERPACK" check --password secret packed
	"$ETERPACK" extract --password secret packed unpacked
	assert_same_tree sample unpacked
}

@test "extract fails with a wrong password" {
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

@test "update fails when another update of the same backup is running" {
	require_cmd flock
	mkdir -p sample/a packed
	echo a >sample/a/file
	# the process holding the lock is sleep itself, so kill releases it
	(exec 9>packed/.lock && flock 9 && exec sleep 30) >/dev/null 2>&1 3>&- &
	local pid=$!
	sleep 1
	run ! "$ETERPACK" update sample packed
	[[ "$output" == *"Another eterpack"* ]]
	kill "$pid"
	wait "$pid" || true
	"$ETERPACK" update sample packed
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

@test "extract, compare and check fail for a dir without archives" {
	mkdir empty sample
	run ! "$ETERPACK" extract empty unpacked
	run ! "$ETERPACK" compare empty sample
	run ! "$ETERPACK" check empty
}

@test "extract fails for a broken archive" {
	create_tree sample
	"$ETERPACK" update sample packed
	local part
	part="$(ls packed/td-*/td-*.000001.zpaq | head -n1)"
	dd if=/dev/urandom of="$part" bs=1 count=4096 seek=1024 conv=notrunc 2>/dev/null
	run ! "$ETERPACK" extract packed unpacked
}

@test "unknown command fails" {
	run ! "$ETERPACK" foo
	run -0 "$ETERPACK" --help
}

# list archive parts with sizes
list_parts()
{
	(cd "$1" && find . -name '*.zpaq' -printf '%P %s\n' | LC_ALL=C sort)
}

check_no_new_parts()
{
	create_tree sample
	"$ETERPACK" update "$@" sample packed
	local before
	before="$(list_parts packed)"
	"$ETERPACK" update "$@" sample packed
	"$ETERPACK" update "$@" sample packed
	[ "$(list_parts packed)" = "$before" ]
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "updates without changes add no parts" {
	check_no_new_parts
}

@test "updates without changes add no parts, --depth 0" {
	check_no_new_parts --depth 0
}

@test "updates without changes add no parts, --depth 2" {
	check_no_new_parts --depth 2
}

@test "updates without changes add no parts, --singlearchive" {
	check_no_new_parts --singlearchive
}

@test "updates without changes add no parts, --noattribute" {
	create_tree sample
	"$ETERPACK" update --noattribute sample packed
	local before
	before="$(list_parts packed)"
	"$ETERPACK" update --noattribute sample packed
	[ "$(list_parts packed)" = "$before" ]
}

@test "updates without changes add no parts, --password" {
	create_tree sample
	"$ETERPACK" update --password secret sample packed
	local before
	before="$(list_parts packed)"
	"$ETERPACK" update --password secret sample packed
	[ "$(list_parts packed)" = "$before" ]
	echo changed >sample/rootfile
	"$ETERPACK" update --password secret sample packed
	[ "$(list_parts packed)" != "$before" ]
	"$ETERPACK" extract --password secret packed unpacked
	assert_same_tree sample unpacked
}

@test "an update with changes adds parts and is restored" {
	create_tree sample
	"$ETERPACK" update sample packed
	"$ETERPACK" update sample packed
	local d
	d="$(basename "$(ls -d sample/td-* | head -n1)")"
	[ ! -e "packed/$d/$d.000002.zpaq" ]
	echo changed >"sample/$d/new-file"
	"$ETERPACK" update sample packed
	[ -e "packed/$d/$d.000002.zpaq" ]
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "update refuses an archive without the index and keeps its parts" {
	create_tree sample
	"$ETERPACK" update sample packed
	local d
	d="$(basename "$(ls -d sample/td-* | head -n1)")"
	rm "packed/$d/$d.000000.zpaq"
	touch "sample/$d/new-file"
	run ! "$ETERPACK" update sample packed
	[[ "$output" == *"index"*"missing"* ]]
	[ -e "packed/$d/$d.000001.zpaq" ]
	[ -z "$(find packed -name '*.broken')" ]
}

@test "update refuses to add a part after a gap" {
	create_tree sample
	"$ETERPACK" update sample packed
	local d
	d="$(basename "$(ls -d sample/td-* | head -n1)")"
	echo changed >"sample/$d/new-file"
	"$ETERPACK" update sample packed
	# the last part is lost
	rm "packed/$d/$d.000002.zpaq"
	echo changed again >"sample/$d/new-file"
	run ! "$ETERPACK" update sample packed
	[[ "$output" == *"missing"* ]]
	[ ! -e "packed/$d/$d.000003.zpaq" ]
}

@test "update works when the parts are moved away and only the index is kept" {
	create_tree sample
	export PACKEDDIR="$BATS_TEST_TMPDIR/packed" MOVEDDIR="$BATS_TEST_TMPDIR/moved"
	"$ETERPACK" update --execute "$BATS_TEST_DIRNAME/move-parts.sh" sample packed
	[ -z "$(find packed -name '*.000001.zpaq')" ]
	local d
	d="$(basename "$(ls -d sample/td-* | head -n1)")"
	echo changed >"sample/$d/new-file"
	"$ETERPACK" update --execute "$BATS_TEST_DIRNAME/move-parts.sh" sample packed
	[ -e "moved/$d/$d.000002.zpaq" ]
	# put the parts back and restore
	cp -a moved/. packed/
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

# add a version to the --depth 0 --noattribute backup like the old eterpack did
old_zpaq_add()
{
	mkdir -p packed
	zpaq add "packed/root.??????.zpaq" ./sample -to . -index packed/root.000000.zpaq >/dev/null
}

@test "compact removes empty parts and keeps all versions" {
	# no symlinks and groups: the backup is made without attributes
	mkdir -p sample/dir
	echo data >sample/dir/file
	echo first >sample/rootfile
	old_zpaq_add
	cp -a sample state1
	old_zpaq_add
	old_zpaq_add
	sleep 1
	echo second >sample/rootfile
	old_zpaq_add
	cp -a sample state2
	old_zpaq_add
	rm sample/rootfile
	old_zpaq_add
	old_zpaq_add
	[ "$(stat -c %s packed/root.000002.zpaq)" = 104 ]
	[ -e packed/root.000007.zpaq ]

	"$ETERPACK" compact packed
	[ -e packed/root.000003.zpaq ]
	[ ! -e packed/root.000004.zpaq ]
	[ -z "$(ls -A packed | grep -F .eterpack.compact)" ]
	"$ETERPACK" check packed

	"$ETERPACK" extract --noattribute packed unpacked
	assert_same_tree sample unpacked
	"$ETERPACK" extract --noattribute --rollback 1 packed unpacked1
	assert_same_tree state1 unpacked1
	"$ETERPACK" extract --noattribute --rollback 2 packed unpacked2
	assert_same_tree state2 unpacked2

	# nothing to do the second time, and the next update works
	local before
	before="$(list_parts packed)"
	"$ETERPACK" compact packed
	[ "$(list_parts packed)" = "$before" ]
	echo third >sample/rootfile
	"$ETERPACK" update --depth 0 --noattribute sample packed
	[ -e packed/root.000004.zpaq ]
	"$ETERPACK" extract --noattribute packed unpacked3
	assert_same_tree sample unpacked3
}

@test "compact removes empty parts of dir archives" {
	create_tree sample
	"$ETERPACK" update sample packed
	local d
	d="$(basename "$(ls -d sample/td-* | head -n1)")"
	# the old eterpack added an empty version on every update
	(cd sample && zpaq add "../packed/$d/$d.??????.zpaq" "./$d" -to "$d" -index "../packed/$d/$d.000000.zpaq" >/dev/null)
	[ "$(stat -c %s "packed/$d/$d.000002.zpaq")" = 104 ]
	"$ETERPACK" compact packed
	[ ! -e "packed/$d/$d.000002.zpaq" ]
	"$ETERPACK" extract packed unpacked
	assert_same_tree sample unpacked
}

@test "compact refuses encrypted backups" {
	create_tree sample
	"$ETERPACK" update --password secret sample packed
	run ! "$ETERPACK" compact packed
	[[ "$output" == *"ncrypted"* ]]
}

@test "update refuses a backup with an interrupted compact" {
	create_tree sample
	"$ETERPACK" update sample packed
	mkdir packed/.eterpack.compact.root
	run ! "$ETERPACK" update sample packed
	[[ "$output" == *"compact"* ]]
	# compact without the .ready mark starts again
	"$ETERPACK" compact packed
	[ ! -e packed/.eterpack.compact.root ]
	"$ETERPACK" update sample packed
}
