#!/bin/sh
# Build the test image and run bats tests inside the container.
# Usage: tests/run-in-container.sh [bats args]   (default: all tests/*.bats)
# Env: BASE=alt:p11 to use another base image, RUN_KNOWN_BUGS=1 to run known bug tests

TOPDIR="$(cd "$(dirname "$0")/.." && pwd -P)"
BASE="${BASE:-alt:sisyphus}"
IMAGE="eterbackup-test:$(echo "$BASE" | tr ':/' '--')"

docker build -q --build-arg BASE="$BASE" -t "$IMAGE" "$TOPDIR/tests/container" >/dev/null || exit

[ -n "$1" ] || set -- tests

TTY=''
[ -t 1 ] && TTY='-t'

exec docker run --rm $TTY \
	-e RUN_KNOWN_BUGS \
	-v "$TOPDIR:/src:ro" \
	"$IMAGE" bats "$@"
