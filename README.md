# Etersoft Backup Tools

Etersoft Backup Tools are intended to solve typical backup tasks.

See the detailed Russian description here: http://wiki.etersoft.ru/Eterbackup

## Tools

- **eterpack** packs files from a directory tree into a few archive files.
  It uses the great archiver [ZPAQ](http://mattmahoney.net/dc/zpaq.html) to create the archives.
- **etertimemachine** backs up a file tree and rotates its snapshots (hard-linked copies named by date or number).
- **eterremove** removes obsolete files and directories by age or total size, and removes empty directories.
- **eterattrstore** is a helper for eterpack. It saves owner/group (with metastore) and special files
  (devices, fifos, symlinks, with pax), which zpaq does not store. zpaq itself keeps file contents,
  permission bits and mtime (in whole seconds) only, and silently skips symlinks and special files.

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
--noattribute        do not save owner/group and special files (zpaq still keeps permissions)
--singlearchive      pack all subdirs into one archive
--followlinks        follow symlinks for the primary dirs
--rollback N|DATE    (for restore) roll back to the N'th update, -N from the end, or to the date
```


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

## What is used

- **zpaq 7.15** (eterpack checks the exact version) stores file contents, permission bits and
  mtime (in whole seconds). It deduplicates data and appends every update as a new part
  (`name.000001.zpaq`, `name.000002.zpaq`, ...), `name.000000.zpaq` is the index of the parts.
  zpaq does not store owner/group and skips symlinks, fifos and devices.
- **metastore** saves owner/group and permissions to `.metadata`.
- **pax** saves symlinks, fifos and devices to `.eterpack.special.files.pax` (sv4cpio format,
  backups made before 1.11 use ustar and are restored as well).
- Both files are created in the root of the source dir during `eterpack update`, packed into the
  `root` archive and removed afterwards. On restore they are applied and removed too.
- **rsync** and `cp -al` (hard links) are used by etertimemachine.
- **log2rotate** from pylog2rotate selects the snapshots to delete for `etertimemachine delete`.
- eterremove uses find, xargs and rm only.

## Limitations

- The source dir must be writable: eterpack writes the metadata files into its root.
  Use `--noattribute` for read-only sources (owner/group and special files are not saved then).
- mtime is kept in whole seconds (zpaq).
- Backslash in names (zpaq 7.15 treats it as a path separator on extract): files with a backslash
  are restored with an extra empty dir named by the part before the backslash, and files inside
  dirs with a backslash in the name are not restored at all.
- Names with a newline are not supported for the dirs packed into separate archives
  (the dirs at `--depth` level): update fails.
- Files and dirs removed from the source are kept in the backup, and restored, when they are
  above the `--depth` level (whole packed dirs and files in the `root` archive).
  Removing inside a packed dir is tracked.
- Empty dirs above the `--depth` level are not saved (`--depth` 2 and more).
- With `--followlinks` owner/group and special files inside the linked dirs are not saved.
- `compare` checks contents, sizes, dates and permissions of files. It does not check owner/group,
  special files and dir dates, and does not report new files above the `--depth` level.
- Always use the same source dir name for the same backup.

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
