#!/usr/bin/env bats
# etertimemachine: update, rotate and delete

setup()
{
	load test_helper
	require_cmd rsync
	common_setup
	mkdir -p sample/dir
	echo first >sample/dir/file
	echo root >sample/rootfile
}

@test "first update copies the tree to last" {
	"$ETERTM" update sample tm
	[ "$(ls tm)" = last ]
	diff -r sample tm/last
	[ ! -e tm/status ]
}

@test "second update rotates last to a dated dir and syncs" {
	"$ETERTM" update sample tm
	echo second >sample/dir/file
	"$ETERTM" update sample tm
	local today
	today="$(date --rfc-3339=date)"
	[ "$(cat "tm/$today/dir/file")" = first ]
	[ "$(cat tm/last/dir/file)" = second ]
	diff -r sample tm/last
}

@test "symlinks pointing outside the tree are kept by the first and the next updates" {
	ln -s /etc/hostname sample/abs-link
	ln -s ../../outside sample/dir/up-link
	ln -s file sample/dir/rel-link
	"$ETERTM" update sample tm
	assert_same_tree sample tm/last
	# new and changed links are synced by rsync
	ln -s /etc/os-release sample/abs-link2
	ln -sfn ../../changed sample/dir/up-link
	"$ETERTM" update sample tm
	assert_same_tree sample tm/last
	[ "$(readlink "tm/$(date --rfc-3339=date)/dir/up-link")" = ../../outside ]
}

@test "update removes deleted files from last" {
	"$ETERTM" update sample tm
	rm sample/rootfile
	"$ETERTM" update sample tm
	[ ! -e tm/last/rootfile ]
}

@test "the third update on the same day fails" {
	"$ETERTM" update sample tm
	"$ETERTM" update sample tm
	run ! "$ETERTM" update sample tm
}

@test "--force skips rotating when the dated dir exists" {
	"$ETERTM" update sample tm
	"$ETERTM" update sample tm
	echo "third version" >sample/dir/file
	"$ETERTM" update --force sample tm
	[ "$(cat tm/last/dir/file)" = "third version" ]
}

@test "--method number names rotated dirs e1, e2" {
	"$ETERTM" update --method number sample tm
	"$ETERTM" update --method number sample tm
	"$ETERTM" update --method number sample tm
	[ -d tm/e1 ]
	[ -d tm/e2 ]
	[ ! -e tm/e3 ]
}

@test "--link hard-links files from the source" {
	"$ETERTM" update --link sample tm
	[ "$(stat -c %i sample/rootfile)" = "$(stat -c %i tm/last/rootfile)" ]
}

@test "rotate creates last for the first time, then rotates" {
	mkdir tm
	"$ETERTM" rotate tm
	[ -d tm/last ]
	echo data >tm/last/file
	"$ETERTM" rotate tm
	local today
	today="$(date --rfc-3339=date)"
	[ -f "tm/$today/file" ]
	[ -f tm/last/file ]
	[ "$(stat -c %i "tm/$today/file")" = "$(stat -c %i tm/last/file)" ]
	run ! "$ETERTM" rotate tm
}

@test "interrupted copying for rotate is rolled back" {
	"$ETERTM" update sample tm
	local today
	today="$(date --rfc-3339=date)"
	# cp -al was interrupted
	mkdir "tm/$today.tmp"
	echo rotate >tm/status
	echo second >sample/dir/file
	"$ETERTM" update sample tm
	[ ! -e "tm/$today.tmp" ]
	[ ! -e tm/status ]
	[ "$(cat "tm/$today/dir/file")" = first ]
	diff -r sample tm/last
}

@test "interrupted rotate is finished" {
	"$ETERTM" update sample tm
	local today
	today="$(date --rfc-3339=date)"
	# last is moved to the dated dir, but the copy is not moved to last yet
	cp -al tm/last "tm/$today.tmp"
	mv tm/last "tm/$today"
	echo rotate >tm/status
	"$ETERTM" rotate --force tm
	[ -d tm/last ]
	[ ! -e "tm/$today.tmp" ]
	[ ! -e tm/status ]
	diff -r sample tm/last
	diff -r sample "tm/$today"
}

@test "interrupted sync is continued by update and blocks rotate" {
	"$ETERTM" update sample tm
	echo sync >tm/status
	run ! "$ETERTM" rotate tm
	[[ "$output" == *"run update"* ]]
	echo second >sample/dir/file
	"$ETERTM" update sample tm
	# no rotating, the sync is just finished
	[ "$(ls tm)" = last ]
	diff -r sample tm/last
}

@test "update fails when another etertimemachine works with the dir" {
	"$ETERTM" update sample tm
	run ! flock tm/.lock "$ETERTM" update sample tm
	[[ "$output" == *"Another etertimemachine"* ]]
}

@test "delete thins dated dirs with log2" {
	require_cmd log2rotate epm
	mkdir -p tm/last
	local i
	for i in $(seq 0 40) ; do
		mkdir "tm/$(date --rfc-3339=date -d "$i days ago")"
	done
	"$ETERTM" delete --method date --thinner log2 tm
	local left
	left="$(ls -d tm/????-??-?? | wc -l)"
	[ "$left" -lt 41 ]
	[ "$left" -gt 1 ]
	[ -d "tm/$(date --rfc-3339=date)" ]
	[ -d tm/last ]
}

@test "delete with --thinner lastN keeps N last dated dirs" {
	mkdir -p tm/last
	local i
	for i in $(seq 0 9) ; do
		mkdir "tm/$(date --rfc-3339=date -d "$i days ago")"
	done
	# interrupted delete is continued
	echo delete >tm/status
	"$ETERTM" delete --method date --thinner last3 tm
	[ "$(ls -d tm/????-??-?? | wc -l)" = 3 ]
	[ -d "tm/$(date --rfc-3339=date)" ]
	[ -d "tm/$(date --rfc-3339=date -d "2 days ago")" ]
	[ -d tm/last ]
	[ ! -e tm/status ]
	run ! "$ETERTM" delete --method date --thinner last0 tm
	run ! "$ETERTM" delete --method date --thinner lastx tm
}

@test "unknown --method fails" {
	run ! "$ETERTM" update --method foo sample tm
	[ ! -e tm ]
}

@test "delete requires --thinner log2" {
	mkdir -p tm/last
	run ! "$ETERTM" delete tm
}

@test "unknown command fails" {
	run ! "$ETERTM" foo
	run -0 "$ETERTM" --help
}
