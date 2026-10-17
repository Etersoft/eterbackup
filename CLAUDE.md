# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Etersoft Backup Tools: a set of standalone shell scripts in `bin/` (no build step), packaged for ALT Linux via gear (`.gear/`, `eterbackup.spec`). Detailed Russian docs: http://wiki.etersoft.ru/Eterbackup

- `eterpack` (bash): packs a directory tree into a few append-only, deduplicated ZPAQ archives, one per subdirectory at a chosen depth.
- `eterattrstore` (bash): helper called by `eterpack`. It saves owner/group (metastore) and special files such as devices, fifos and symlinks (pax). zpaq itself keeps only contents, permission bits and mtime in whole seconds, and silently skips symlinks and special files.
- `etertimemachine` (POSIX sh): rsync/`cp -al` snapshot rotation (`last` plus dated/numbered dirs), with log2 thinning through `log2rotate`.
- `eterremove` (POSIX sh): removes old files and dirs by age or total size, and empty dirs. It is a dry run unless `--notest` is given.

Runtime dependencies: `zpaq` (**exactly v7.15**; `eterpack` refuses to run with any other version), `metastore` and `pax` (eterattrstore), `rsync`, `log2rotate`/`pylog2rotate`.

## Commands

```sh
./check_code.sh                 # checkbashisms + shellcheck on bin/* (with project exclusions)
./check_code.sh bin/eterpack    # shellcheck a single file

tests/run-in-container.sh                                   # all tests (same as `make check`)
tests/run-in-container.sh tests/eterpack-exclude.bats       # one file
tests/run-in-container.sh -f 'password' tests               # tests matching a regex
RUN_KNOWN_BUGS=1 tests/run-in-container.sh                  # also run known bug tests
BASE=alt:p11 tests/run-in-container.sh                      # other base image
```

**Run tests only in the container, never on the host.** `run-in-container.sh` builds `tests/container/Dockerfile` (ALT with zpaq 7.15, metastore, pax, rsync, pylog2rotate, eepm, bats) and runs bats as the non-root user `tester`, with the repo mounted read-only at `/src`. Use the real path (`/srv/lav/...`); the docker daemon cannot follow the `/home/lav/Projects` symlink.

Tests use bats-core (`tests/*.bats`, helpers in `tests/test_helper.bash`). Each test works in its own `$BATS_TEST_TMPDIR`. `assert_same_tree` compares contents plus type, mode, owner, group, link target and file mtime in whole seconds, because zpaq keeps seconds only and dir mtimes are not restored. `TEST_GROUP` (set in the image) is a secondary group, so the tests can check that group ownership is restored. Tests for confirmed but unfixed bugs call `known_bug "..."` and are skipped unless `RUN_KNOWN_BUGS` is set. When you fix such a bug, remove the `known_bug` line.

Installation: `make install DESTDIR=... bindir=... mandir=...` copies `bin/*` (files without `-` in the name) and `man/*`.

## eterpack architecture

Archive layout produced by `eterpack update SRC DST [--depth N]`:
- For every directory at exactly depth N (`MINDEPTH=MAXDEPTH=N`), it creates `DST/<reldir>/<name>.??????.zpaq`, a zpaq multipart archive: `.000000.zpaq` is the index, and each update appends a new `.00000N.zpaq` part. zpaq is run from the parent dir (`cd "$BACKUPDIR/$reldir/.."`) so that paths inside the archive start with `<name>/`.
- Files at depths shallower than N go into `DST/root.??????.zpaq`, together with the metafiles from `eterattrstore` (`.metadata`, `.eterpack.special.files.pax`). Those metafiles are written temporarily into the **source** tree and removed afterwards, so the source must be writable.
- `--depth 0` runs `update_archive`, which packs the whole tree into one `root` archive. `--singlearchive` puts every subdir into the single root archive.
- After an update, `DST` also holds `dirs.list`, `files.list`, `.last-updated`, and `.status`/`.status_ext` while a run is in progress or after it fails. The `status` command reads these files. When zpaq reports "archive exists", the broken part is renamed to `.broken` so that the next run can continue.
- `extract`/`compare`/`test` find every `*.000000.zpaq` and run zpaq on the `??????` glob, never on a single part.

`--exclude` (can be repeated, stored in the `EXCLUDES` array): a value starting with `/` is a path relative to the source root. It skips that dir, or anything below it, or becomes a zpaq `-not` pattern when the excluded path lies inside a packed dir. A value without `/` matches a directory basename at the packing depth. The same matching rules are implemented in three places (`is_excluded_dir`/`list_dirs`, the loop in `update_dump`, and `update_archive`), so keep them in sync. `tests/eterpack-exclude.bats` covers the combinations.

Filenames with spaces and special characters must work. Quote paths and use arrays for zpaq argument lists (see `create_spaces_tree`/`create_symbols_tree` and the `*-spaces` tests). `$CHECKSUM`, `$PASSWORDARG`, `$ROLLBACK` and `$FOLLOWLINKS` are left unquoted on purpose, because they may be empty or contain several words.

## Conventions

- Scripts other than `eterpack`/`eterattrstore` are `#!/bin/sh`, so keep them free of bashisms (`check_code.sh` runs `checkbashisms`).
- In `etertimemachine` and `eterremove`, options are parsed positionally and must be given in a fixed order.
- A release bumps `Version` and adds an entry to `%changelog` in `eterbackup.spec` (commit message `X.Y-altN`). The `VERSION` strings inside the scripts are tracked separately.
