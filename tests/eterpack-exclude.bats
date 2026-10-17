#!/usr/bin/env bats
# eterpack --exclude handling at different --depth levels

setup()
{
	load test_helper
	require_zpaq
	common_setup
	create_tree sample
}

# check_exclude DEPTH "EXCLUDE OPTIONS" EXCLUDED_PATH...
# pack with the options, then check that the excluded paths are missed
# and everything else is the same as in the source tree
check_exclude()
{
	local depth="$1" excludes="$2"
	shift 2

	local args=() ex
	# exclude names in tests have no spaces, so split on whitespace
	for ex in $excludes ; do
		args+=(--exclude "$ex")
	done

	"$ETERPACK" update --depth "$depth" "${args[@]}" sample packed
	"$ETERPACK" check packed
	"$ETERPACK" extract packed unpacked

	local p
	for p in "$@" ; do
		if [ -e "unpacked/$p" ] ; then
			echo "excluded $p exists"
			return 1
		fi
	done

	copy_tree_without sample expected "$@"
	"$ETERPACK" compare packed expected
	if [ "$depth" -ge 2 ] ; then
		assert_same_tree_pruned expected unpacked
	else
		assert_same_tree expected unpacked
	fi
}

@test "depth 0, exclude by name" {
	check_exclude 0 stage1 stage1
}

@test "depth 0, exclude by path" {
	check_exclude 0 /stage1 stage1
}

@test "depth 1, exclude by name" {
	check_exclude 1 stage1 stage1
	[ -d unpacked/stage0 ]
}

@test "depth 1, exclude by path" {
	check_exclude 1 /stage1 stage1
}

@test "depth 1, exclude by path inside a packed dir" {
	check_exclude 1 /stage1/stage2 stage1/stage2
	[ -d unpacked/stage1/stage22 ]
}

@test "depth 1, a name with a slash excludes nothing" {
	check_exclude 1 stage1/stage2
	[ -d unpacked/stage1/stage2 ]
}

@test "depth 1, several excludes" {
	check_exclude 1 "stage0 /stage1/stage22" stage0 stage1/stage22
}

@test "depth 1, exclude a root file by path" {
	echo data >sample/rootfile
	check_exclude 1 /rootfile rootfile
}

@test "depth 2, exclude by name" {
	check_exclude 2 stage2 stage1/stage2
}

@test "depth 2, exclude by path above the depth" {
	check_exclude 2 /stage1 stage1
}

@test "depth 2, exclude by path at the depth" {
	check_exclude 2 /stage1/stage2 stage1/stage2
}

@test "depth 3, exclude by name" {
	check_exclude 3 stage3 stage1/stage2/stage3 stage1/stage22/stage3
}

@test "depth 3, exclude by path at level 1" {
	check_exclude 3 /stage1 stage1
}

@test "depth 3, exclude by path at level 2" {
	check_exclude 3 /stage1/stage2 stage1/stage2
}

@test "depth 3, exclude by path at level 3" {
	check_exclude 3 /stage1/stage2/stage3 stage1/stage2/stage3
	[ -d unpacked/stage1/stage22/stage3 ]
}

@test "depth 3, exclude by path below the depth" {
	check_exclude 3 /stage1/stage2/stage3/stage4 stage1/stage2/stage3/stage4
	[ -d unpacked/stage1/stage2/stage3 ]
}

@test "several excludes with spaces and root files with spaces (ALT bug 32816)" {
	rm -rf sample
	create_spaces_tree sample
	"$ETERPACK" update --exclude "space1 first" --exclude "пробел1 second" sample packed
	"$ETERPACK" extract packed unpacked
	[ ! -e "unpacked/space1 first" ]
	[ ! -e "unpacked/пробел1 second" ]
	[ -d "unpacked/space1 second" ]
	[ -f "unpacked/file3 пробел" ]
}

@test "--exclude without a name fails" {
	run ! "$ETERPACK" update --exclude
	run ! "$ETERPACK" update --exclude "" sample packed
}
