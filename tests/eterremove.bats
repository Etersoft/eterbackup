#!/usr/bin/env bats
# eterremove: removing old files, old dirs and empty dirs

setup()
{
	load test_helper
	common_setup
}

# dirs old1..old3 (10 days old), new1..new2 (fresh)
create_aged_dirs()
{
	local d
	for d in old1 old2 old3 new1 new2 ; do
		mkdir -p "sample/$d/sub"
		echo data >"sample/$d/sub/file"
	done
	for d in old1 old2 old3 ; do
		touch -d "10 days ago" "sample/$d/sub/file" "sample/$d/sub" "sample/$d"
	done
}

@test "remove dirs: dry run removes nothing" {
	create_aged_dirs
	run -0 "$ETERREMOVE" remove --days 5 dirs sample
	[[ "$output" == *"test run"* ]]
	[[ "$output" == *"old1"* ]]
	[ -d sample/old1 ]
}

@test "remove dirs: older than N days" {
	create_aged_dirs
	"$ETERREMOVE" remove --days 5 --notest dirs sample
	[ ! -e sample/old1 ]
	[ ! -e sample/old2 ]
	[ ! -e sample/old3 ]
	[ -d sample/new1 ]
	[ -d sample/new2 ]
}

@test "remove dirs: --exclude keeps the dir" {
	create_aged_dirs
	"$ETERREMOVE" remove --exclude old2 --days 5 --notest dirs sample
	[ ! -e sample/old1 ]
	[ -d sample/old2 ]
}

@test "remove files: older than N days and empty dirs" {
	mkdir -p sample/a sample/b
	echo old >sample/a/old
	echo new >sample/a/new
	echo old >sample/b/old
	touch -d "10 days ago" sample/a/old sample/b/old
	"$ETERREMOVE" remove --depth 2 --days 5 --notest files sample
	[ ! -e sample/a/old ]
	[ -f sample/a/new ]
	[ ! -e sample/b ]
	[ -d sample ]
}

@test "remove files: --size keeps the newest files within the limit" {
	known_bug "--size removes the newest files instead of the oldest"
	create_datefiles sample
	"$ETERREMOVE" remove --size 8 files sample
	[ -e sample/tf-1 ]
	"$ETERREMOVE" remove --size 8 --notest files sample
	local i
	for i in 1 2 3 4 5 6 ; do
		[ ! -e "sample/tf-$i" ]
	done
	for i in 7 8 9 ; do
		[ -e "sample/tf-$i" ]
	done
}

@test "remove empty: removes empty dirs and broken links" {
	mkdir -p sample/empty1/empty2 sample/full
	echo data >sample/full/file
	ln -s nonexistent sample/broken
	ln -s full/file sample/good
	touch -d "1 hour ago" sample/empty1/empty2 sample/empty1
	"$ETERREMOVE" remove --days 1 --notest empty sample
	[ ! -e sample/empty1 ]
	[ ! -L sample/broken ]
	[ -L sample/good ]
	[ -f sample/full/file ]
}

@test "files with spaces in names" {
	mkdir -p "sample/dir one"
	echo old >"sample/dir one/old file"
	echo new >"sample/dir one/new file"
	touch -d "10 days ago" "sample/dir one/old file"
	"$ETERREMOVE" remove --depth 1 --days 5 --notest files sample
	[ ! -e "sample/dir one/old file" ]
	[ -f "sample/dir one/new file" ]
}

@test "wrong parameters fail" {
	mkdir sample
	run ! "$ETERREMOVE" remove --notest files sample
	run ! "$ETERREMOVE" remove --days 0 --notest files sample
	run ! "$ETERREMOVE" remove --days 5 --notest files nonexistent
	run ! "$ETERREMOVE" remove --size 1 --notest dirs sample
	run ! "$ETERREMOVE" foo
	run -0 "$ETERREMOVE" --help
}
