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
	known_bug "--method number fails: ROTATEDIR is checked before it is set"
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

@test "interrupted status blocks rotate" {
	"$ETERTM" update sample tm
	echo rotate >tm/status
	run ! "$ETERTM" update sample tm
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

@test "delete requires --thinner log2" {
	mkdir -p tm/last
	run ! "$ETERTM" delete tm
}

@test "unknown command fails" {
	run ! "$ETERTM" foo
	run -0 "$ETERTM" --help
}
