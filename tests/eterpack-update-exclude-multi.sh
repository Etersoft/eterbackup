#!/bin/sh
# several --exclude options and files with spaces in the root dir (ALT bug 32816)

BASEDIR=/tmp/eterbackup-TD
ETERPACK=$(pwd)/../bin/eterpack

rm -rf $BASEDIR

. ./eterbackup-functions.sh

create_spaces_tree $BASEDIR/sample

cd $BASEDIR || exit 1

$ETERPACK update --exclude "space1 first" --exclude "пробел1 second" sample packed || fatal "Error in update"

$ETERPACK extract packed unpacked || fatal "Error in extract"

[ -d "unpacked/space1 first" ] && fatal "excluded dir 'space1 first' exists"
[ -d "unpacked/пробел1 second" ] && fatal "excluded dir 'пробел1 second' exists"
[ -d "unpacked/space1 second" ] || fatal "dir 'space1 second' is missed"
[ -f "unpacked/file3 пробел" ] || fatal "root file with spaces is missed"

echo "Done! OK!"
echo "Please, check and remove $BASEDIR"
