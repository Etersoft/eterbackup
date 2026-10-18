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
and a `root` archive for the files above that depth. Every update appends a new part to each archive
with changes (a part without changes is not kept), so older states can be restored with `--rollback`.

```sh
eterpack update /path/from /path/to        # create or update a backup
eterpack restore /path/backup /path/to     # restore a backup
eterpack compare /path/backup /path/to     # compare a backup with local files
eterpack test /path/backup                 # test backup integrity
eterpack compact /path/backup              # remove empty parts left by older eterpack versions
eterpack info [--all] /path/backup         # print archives with their versions and sizes
eterpack status /path/backup               # print backup status
```

Main options:

```
--depth N            set depth for subdirs (1 by default)
--exclude name       exclude dir 'name' (a /full/path from the source root or a dir name), can be repeated
--exclude-from file  read --exclude values from file (one per line, empty lines and # comments are skipped)
--execute command    execute 'command' after every archive
--checksum           compare file contents, not only dates
--password pass      encrypt/decrypt archives
--noattribute        do not save owner/group and special files (zpaq still keeps permissions)
--singlearchive      pack all subdirs into one archive
--followlinks        follow symlinks for the primary dirs
--rollback N|DATE    (for restore) roll back to the N'th version, -N from the end, or to the date
```

`compare` checks the files with zpaq, and owner/group, permissions and special files with the saved
metadata. Give it the same `--exclude` options as `update` when comparing with the source dir, so the
special files in the excluded dirs are skipped. `test` decompresses every archive without writing files
(zpaq checks the SHA-1 of every fragment) and checks that every dir from `dirs.list` has its archive.
`info` reads the indexes only, so it works when the parts are moved away (`--all` lists every version
with its date, use it to choose a date for `--rollback`).


## etertimemachine

```sh
etertimemachine update [--link] /path/from /path/to       # rotate 'last' and sync it with /path/from
etertimemachine rotate /path/to                           # copy 'last' into a dir named by --method
etertimemachine delete --thinner log2 /path/to            # thin dated snapshots logarithmically
etertimemachine delete --thinner last30 /path/to          # keep 30 last dated snapshots
```

The rotated dirs are named with `--method date|datetime|number` (date by default).
The target dir is locked (`.lock`) while etertimemachine works with it. The `status` file is left
there if a run is interrupted: the next update continues an interrupted sync, update and rotate
finish or roll back an interrupted rotating, and delete runs an interrupted deleting again.

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
- With `--followlinks` metastore data for every linked dir is saved to `.eterpack.follow/`.
- Special files in the dirs excluded with `--exclude` are not saved (backups made before 1.13 have
  them, and restore creates such dirs with the special files only).
- During `eterpack update` these files are written to a temporary dir in the backup dir (the source
  is not changed) and packed into the root of the `root` archive. On restore they are applied
  and removed.
- **flock** (util-linux) locks the backup dir (`.lock`), so two updates of the same backup
  can't run at once. etertimemachine locks its target dir the same way.
- **rsync** and `cp -al` (hard links) are used by etertimemachine.
- **log2rotate** from pylog2rotate selects the snapshots to delete for `etertimemachine delete`.
- eterremove uses find, xargs and rm only.

## Limitations

- The names `.metadata`, `.eterpack.special.files.pax` and `.eterpack.follow` in the root of the
  source dir are reserved: update fails if any of them exists (unless `--noattribute` is used).
- `--password` is passed to zpaq on the command line, so other local users can see it in `ps`.
- Restore only backups you trust: special files and metadata are applied by pax and metastore
  with the paths stored in the backup.
- mtime is kept in whole seconds (zpaq).
- Backslash in names (zpaq 7.15 treats it as a path separator on extract): files with a backslash
  are restored with an extra empty dir named by the part before the backslash, and files inside
  dirs with a backslash in the name are not restored at all.
- Names with a newline are not supported for the dirs packed into separate archives
  (the dirs at `--depth` level): update fails.
- Files and dirs removed from the source are marked as removed in the backup on the next update
  (older states are still available with `--rollback`). A removed dir which is excluded with
  `--exclude` keeps its last backup.
- `--rollback N` counts the versions of every archive separately, and an archive gets a version
  only when it has changes (with `--singlearchive` every packed dir is a separate version).
  Use `--rollback DATE` to restore the whole backup as it was at some moment.
- zpaq 7.15 can't remove old versions, so the space taken by changed and removed data is never
  freed. Start a new backup dir to drop the history.
- Never remove or truncate parts by hand: zpaq reads parts up to the first missed number, so the
  later parts become invisible, and the next update continues the numbering after the gap.
  Use `eterpack compact` to remove empty parts (left by eterpack before 1.13, 104 bytes each).
  It renumbers the parts and so is not supported for encrypted backups.
- Dirs above the `--depth` level which become empty only due to `--exclude` are not saved.
- `compare` does not check dir dates and mtime of special files, and does not report new files
  above the `--depth` level. Owner/group are compared for the whole source tree, including
  the excluded dirs.
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
`TEST_SH=dash tests/run-in-container.sh` runs the POSIX sh scripts with dash.

Read all about zpaq here:
http://encode.ru/threads/456-zpaq-updates

## Similar projects

- https://www.borgbackup.org/
- https://attic-backup.org/
- http://obnam.org
- https://github.com/flakrat/ghetto-timemachine
- stmpclean (tmpwatch)
