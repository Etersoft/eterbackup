#!/bin/sh
# --execute helper for the tests: move the parts of archive $1 from $PACKEDDIR to $MOVEDDIR
# (keeps the index, like a backup with the parts sent to a remote storage)
arch="$1"
dir="$(dirname "$arch")"
rel="${dir#"$PACKEDDIR"}"
rel="${rel#/}"
mkdir -p "$MOVEDDIR/$rel" || exit
for p in "$dir/$(basename "$arch" .??????.zpaq)".??????.zpaq ; do
	case "$p" in
		*.000000.zpaq|*"??????"*) continue ;;
	esac
	mv "$p" "$MOVEDDIR/$rel/" || exit
done
