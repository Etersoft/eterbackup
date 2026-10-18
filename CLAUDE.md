# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Etersoft Backup Tools: a set of standalone shell scripts in `bin/` (no build step), packaged for ALT Linux via gear (`.gear/`, `eterbackup.spec`). Detailed Russian docs: http://wiki.etersoft.ru/Eterbackup

- `eterpack` (bash): packs a directory tree into a few append-only, deduplicated ZPAQ archives, one per subdirectory at a chosen depth.
- `eterattrstore` (POSIX sh): helper called by `eterpack`. It saves owner/group (metastore) and special files such as devices, fifos and symlinks (pax). zpaq itself keeps only contents, permission bits and mtime in whole seconds, and silently skips symlinks and special files.
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
TEST_SH=dash tests/run-in-container.sh                      # run the POSIX sh scripts with dash
BASE=alt:p11 tests/run-in-container.sh                      # other base image
```

**Run tests only in the container, never on the host.** `run-in-container.sh` builds `tests/container/Dockerfile` (ALT with zpaq 7.15, metastore, pax, rsync, pylog2rotate, eepm, bats) and runs bats as the non-root user `tester`, with the repo mounted read-only at `/src`. Use the real path (`/srv/lav/...`); the docker daemon cannot follow the `/home/lav/Projects` symlink.

Tests use bats-core (`tests/*.bats`, helpers in `tests/test_helper.bash`). Each test works in its own `$BATS_TEST_TMPDIR`. `assert_same_tree` compares contents plus type, mode, owner, group, link target and file mtime in whole seconds, because zpaq keeps seconds only and dir mtimes are not restored. `TEST_GROUP` (set in the image) is a secondary group, so the tests can check that group ownership is restored. Tests for confirmed but unfixed bugs call `known_bug "..."` and are skipped unless `RUN_KNOWN_BUGS` is set. When you fix such a bug, remove the `known_bug` line.

Installation: `make install DESTDIR=... bindir=... mandir=...` copies `bin/*` (files without `-` in the name) and `man/*`.

## eterpack architecture

Archive layout produced by `eterpack update SRC DST [--depth N]`:
- For every directory at exactly depth N (`MINDEPTH=MAXDEPTH=N`), it creates `DST/<reldir>/<name>.??????.zpaq`, a zpaq multipart archive: `.000000.zpaq` is the index, and each update appends a new `.00000N.zpaq` part. zpaq is run from the parent dir as `zpaq add ARCH ./<dir> -to <intname>`. The internal name is the dir name in the source (the link name with `--followlinks`, `reldir` with `--singlearchive`). The `./` prefix, and `./` before an internal name starting with `-`, keep zpaq from parsing names as options. zpaq matches `-not` patterns against the **external** path (`./<dir>/...`) and `-to` sets the internal one.
- Files at depths shallower than N, and empty dirs above depth N, go into `DST/root.??????.zpaq`, together with the metafiles from `eterattrstore` (`METANAMES`: `.metadata`, `.eterpack.special.files.pax`, `.eterpack.follow/N.{path,metadata}` for `--followlinks`). `save_metadir` runs `eterattrstore save --metadir DST/.eterpack.tmp.XXXXXX` and zpaq stores those files in the archive root via `-to`, so the source tree is never written and the archive layout stays compatible with old eterpack. These names in the source root are reserved (`assert_no_metanames`). A missing metafile is passed to zpaq only if the archive has it, so zpaq marks it as removed. `extract` moves the metafiles out of the restored tree before applying them, because the restored root can be read-only.
- `--followlinks`: `list_followed_links` lists symlinked dirs down to depth N. metastore stores real paths for symlinked args, so eterattrstore runs a separate metastore inside every followed dir, and pax saves `link/...` paths while skipping the followed links themselves.
- `--depth 0` runs `update_archive`, which packs the whole tree into one `root` archive. `--singlearchive` puts every subdir into the single root archive.
- After an update, `DST` also holds `dirs.list`, `files.list`, `.last-updated`, and `.status`/`.status_ext` while a run is in progress or after it fails. The `status` command reads these files. When zpaq reports "archive exists", the broken part is renamed to `.broken` so that the next run can continue.
- `extract`/`compare`/`test` find every `*.000000.zpaq` and run zpaq on the `??????` glob, never on a single part.
- Removing: zpaq marks stored files as removed only under the paths it is given. So `update` also passes the names that were removed from the source: `mark_removed_dirs` handles dir archives whose dir is gone, and `list_removed_rootnames` handles the root archive.
- `compare` runs `zpaq list ARCH <top names> -not =` in the dir the archive extracts to. zpaq always exits 0 here, so `compare_archive` counts the `#`/`+`/`-` lines itself, skipping dir lines. Then `compare_metadata` extracts the stored metafiles and runs `eterattrstore compare`: `metastore -c` (only changes of owner/group/mode/type, added and removed files are left to zpaq) and a diff of `pax -v` listings without dates for the special files.
- `--exclude` paths are passed to `eterattrstore save --exclude FILE` (`list_excluded_paths`), so pax skips special files in excluded dirs. metastore has no excludes and saves the whole tree.
- `test` runs `zpaq extract -test` for every archive and checks that every dir from `dirs.list` has its archive (or is in the root archive with `--singlearchive`). `info` lists the versions from the indexes only.
- `update` takes `flock` on `DST/.lock`.
- zpaq writes a 104-byte part with an empty version on every `add` without changes. `zpaq_add` saves the index to `.prev` and, on "0 +added, 0 -removed", restores the index first and then removes the new part (a crash in between leaves an extra part that the next run moves to `.broken`). `keep_stored_metadates` extracts the stored metafiles and copies their dates to unchanged new ones, so the root archive gets no version either.
- zpaq reads parts up to the first missing number and numbers a new part as "versions in the index + 1", so parts must never be removed from the middle. `compact` drops empty parts (0 bytes, or 104 bytes with a `+0 -0` version in `list -all`) by hardlinking the rest renumbered into `.eterpack.compact.<name>/`, rebuilding the index with `zpaq extract ... -index`, checking the version count, writing `.ready` and then swapping. A rerun finishes a swap with `.ready`; `update` refuses to run while such a dir exists. Encrypted archives can't be renumbered (the AES stream depends on the part offsets).

`--exclude` (can be repeated, stored in the `EXCLUDES` array): a value starting with `/` is a path relative to the source root. It skips that dir, or anything below it, or becomes a zpaq `-not` pattern when the excluded path lies inside a packed dir. A value without `/` matches a directory basename at the packing depth. `--exclude-from FILE` adds the lines of FILE to `EXCLUDES`. The same matching rules are implemented in three places (`is_excluded_dir`/`list_dirs`, which also skips dirs below an excluded path, the loop in `update_dump`, and `update_archive`), so keep them in sync. `tests/eterpack-exclude.bats` covers the combinations.

Filenames with spaces and special characters must work. Quote paths, use `read -r`, use `basename --`/`dirname --`, and keep option lists in arrays (`CHECKSUM`, `PASSWORDARG`, `ROLLBACK`, `FOLLOWLINKS`, `EXCLUDEARG`).

## Conventions

- Scripts other than `eterpack` are `#!/bin/sh`, so keep them free of bashisms (`check_code.sh` runs `checkbashisms`).
- In `etertimemachine` and `eterremove`, options are parsed positionally and must be given in a fixed order.
- `etertimemachine` takes `flock` on `ROTATEDIR/.lock`, so a `status` file left in `ROTATEDIR` always means an interrupted run: `recover_rotate` finishes or rolls back a rotating by the `*.tmp` dir, `sync` is continued by `update`, `delete` is run again.
- A release bumps `Version` and adds an entry to `%changelog` in `eterbackup.spec` (commit message `X.Y-altN`). The `VERSION` strings inside the scripts are tracked separately.
