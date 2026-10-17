# Etersoft Backup Tools

Etersoft Backup Tools are intended to solve typical backup tasks.

See the detailed Russian description here: http://wiki.etersoft.ru/Eterbackup

## Tools

- **eterpack** packs files from a directory tree into a few archive files.
  It uses the great archiver [ZPAQ](http://mattmahoney.net/dc/zpaq.html) to create the archives.
- **etertimemachine** backs up a file tree and rotates its snapshots (hard-linked copies named by date or number).
- **eterremove** removes obsolete files and directories by age or total size, and removes empty directories.
- **eterattrstore** is a helper for eterpack. It saves and restores owners, permissions and special files
  (devices, fifos, symlinks), which zpaq does not store.

## eterpack

The goals of the eterpack tool:
- reduce the number of files from many thousands to a few
- use deduplication and append-only files
- multipart archives (one file or more per backup session)

eterpack creates a separate zpaq archive for every directory at the given depth (`--depth`, 1 by default),
and a `root` archive for the files above that depth. Every update appends a new part to each archive,
so older states can be restored with `--rollback`.

```sh
eterpack update /path/from /path/to        # create or update a backup
eterpack restore /path/backup /path/to     # restore a backup
eterpack compare /path/backup /path/to     # compare a backup with local files
eterpack test /path/backup                 # test backup integrity
eterpack status /path/backup               # print backup status
```

Main options:

```
--depth N            set depth for subdirs (1 by default)
--exclude name       exclude dir 'name' (a /full/path from the source root or a dir name), can be repeated
--execute command    execute 'command' after every archive
--checksum           compare file contents, not only dates
--password pass      encrypt/decrypt archives
--noattribute        do not save owner/group, permissions and special files
--singlearchive      pack all subdirs into one archive
--followlinks        follow symlinks for the primary dirs
--rollback N|DATE    (for restore) roll back to the N'th update, -N from the end, or to the date
```

Note: always use the same source dir name for the same backup.

## etertimemachine

```sh
etertimemachine update [--link] /path/from /path/to       # rotate 'last' and sync it with /path/from
etertimemachine rotate /path/to                           # copy 'last' into a dir named by --method
etertimemachine delete --thinner log2 /path/to            # thin dated snapshots logarithmically
```

The rotated dirs are named with `--method date|datetime|number` (date by default).

## eterremove

```sh
eterremove remove --depth 2 --days 30 files /path/to/remove
eterremove remove --exclude current --days 10 dirs /path/to/remove
```

eterremove only shows what would be removed until you add `--notest`.
Options must be given in the order shown by `eterremove --help`.

## Requirements

- zpaq 7.15 (eterpack checks the exact version)
- metastore and pax (for saving attributes)
- rsync (etertimemachine)
- log2rotate from pylog2rotate (`etertimemachine delete`)

## Development

```sh
./check_code.sh                                  # checkbashisms and shellcheck
make check                                       # run all tests in a docker container
tests/run-in-container.sh tests/eterpack.bats    # run one test file
```

The tests use [bats-core](https://github.com/bats-core/bats-core) and run in an ALT Linux
container (`tests/container/Dockerfile`) with zpaq 7.15, metastore, pax and rsync installed.
Tests for known, not yet fixed bugs are skipped unless `RUN_KNOWN_BUGS=1` is set.

Read all about zpaq here:
http://encode.ru/threads/456-zpaq-updates

## Similar projects

- https://www.borgbackup.org/
- https://attic-backup.org/
- http://obnam.org
- https://github.com/flakrat/ghetto-timemachine
- stmpclean (tmpwatch)
