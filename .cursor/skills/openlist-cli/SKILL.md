---
name: openlist-cli
description: Installs, uninstalls, configures, and operates the openlist client CLI (config, fs, strm, --version) for OpenList and AList-compatible servers. Use when installing a GitHub Release archive or a source build, removing the openlist binary, editing ~/.config/openlist/config.yaml, OPENLIST_URL, or OPENLIST_TOKEN, or running list, dirs, get, search, mkdir, rename, copy, move, remove, offline download, or .strm generation.
---

# OpenList CLI

`openlist` in this repository is a client for an OpenList (AList-compatible) file server. It does not start, install, or manage the server process.

When a command disagrees with this skill, trust `openlist <command> --help` and the packages `cmd/`, `config/`, `client/`, and `strm/`, then update the skill. Flags, response fields, and error strings are in [reference.md](reference.md).

## Identify the binary

Confirm the file is this client before running or replacing it. The OpenList server binary uses the same name.

```bash
openlist --help
```

The text must contain "OpenList CLI is a command line interface", and Available Commands must include `config`, `fs`, and `strm`. `openlist fs --help` lists only file subcommands, so it does not identify the binary. Leave a different program in place.

`openlist --help` and `openlist <command> --help` still work when the config file is invalid. `openlist help <command>` and `openlist completion` load config first and fail on invalid YAML.

## Install

Install the matching GitHub Release archive when one exists. Build the current checkout when there is no release or the task needs the current commit. Do not create a tag or trigger a release in order to install.

Release assets are named `openlist_<tag>_<os>_<arch>.tar.gz`. Windows assets are `.zip` files with the same stem. `<tag>` includes the leading `v`, for example `openlist_v0.1.0_linux_amd64.tar.gz`. The file inside is `openlist`, or `openlist.exe` on Windows. The only platforms are `linux`, `darwin`, and `windows`, each with `amd64` and `arm64`. `uname -m` value `x86_64` is `amd64`. `aarch64` is `arm64`.

Download the archive and the `checksums.txt` from the same release. Check the sha256 before extracting. If the destination path already exists, run `--help` on that file and choose another name when it is not this client.

```bash
install -m 0755 openlist "$HOME/.local/bin/openlist"
openlist --version
openlist --help
```

A release binary prints the tag from `--version`. A source build prints `dev`.

Build in an existing checkout. Do not clone again.

```bash
go version
go build -o openlist .
./openlist --version
./openlist --help
```

Go 1.23 or newer is required. The `toolchain` in `go.mod` is `go1.24.12`. The default `GOTOOLCHAIN=auto` downloads that toolchain when needed. The first build needs module downloads.

The module path in `go.mod` is `openlist`. Do not run `go install github.com/.../openlist@latest`. To place a source build on `PATH`, run `go install .` from the repository root. The binary is `$GOBIN/openlist`, or `$(go env GOPATH)/bin/openlist` when `GOBIN` is unset. That binary is also version `dev`. `go install` does not change `PATH`.

To copy the repo binary onto `PATH` without `go install`:

```bash
install -m 0755 ./openlist "$HOME/.local/bin/openlist"
```

For a one-off run, put program arguments after the package path: `go run . fs list --path /`. `go run` prints `dev` as well.

The version flags exist only on the root command: `openlist --version` or `openlist -v`. Stdout is `openlist version <version>`, the exit code is 0, and config is not read. Subcommands reject `--version`. On `config set`, `-v` is the value to store.

## Uninstall

There is no `uninstall` subcommand. Leave the server, its data directory, and its containers in place.

1. Find candidates with `command -v openlist` and `./openlist` in the repo. Run `--help` on each file. Delete a file only when the help text contains both "OpenList CLI is a command line interface" and `strm`. A `go install` copy is `$GOBIN/openlist`, or `$(go env GOPATH)/bin/openlist` when `GOBIN` is unset. Also delete an extracted release binary, the downloaded archive, and `checksums.txt`. Leave the GitHub Release itself in place.
2. When the uninstall includes credentials, delete the directory `"${XDG_CONFIG_HOME:-$HOME/.config}/openlist"`. Its `config.yaml` holds the token and is mode `0600`. Keep that directory when only the binary should be removed.
3. When credentials are removed, delete only the `OPENLIST_URL` and `OPENLIST_TOKEN` lines from shell startup files and the repo `.env`. Remove a completion script only if one was added to a shell startup file.

Afterward, `--help` on the old path must not show this client.

## Configure

Later layers replace earlier ones: defaults, then the config file, then environment variables, then flags passed on this invocation.

| Key | Default | Environment | Flags |
| --- | --- | --- | --- |
| `url` | `http://localhost:5244` | `OPENLIST_URL` | `--url`, `-u` |
| `token` | empty | `OPENLIST_TOKEN` | `--token`, `-t` |

The file is `$XDG_CONFIG_HOME/openlist/config.yaml`, or `~/.config/openlist/config.yaml` when `XDG_CONFIG_HOME` is unset. `config set` creates the directory at mode `0700` and the file at mode `0600`. The only keys are `url` and `token`. Key lookup is case-insensitive.

```bash
env -u OPENLIST_URL -u OPENLIST_TOKEN openlist config set url http://localhost:5244
env -u OPENLIST_URL -u OPENLIST_TOKEN openlist config set token '<token>'
openlist config get url
```

`config set` writes the whole result of `Load()`. An `OPENLIST_URL` or `OPENLIST_TOKEN` value in the environment is saved even when the command changes the other key. Unset both variables before writing. `--url` and `--token` are not written by `config set`.

`config get` and `config list` print the effective values, including environment and flags. `config list` prints the token in plaintext. Report only whether the token is non-empty. Do not paste the token.

`config set` rejects an empty value. To clear the token, unset the environment variables, then edit or delete the file. `config set` cannot repair invalid YAML because it loads the file first. Move the broken file aside or replace it with valid YAML, then run `config set` again. `--url` does not skip a broken config file.

`url` loses leading and trailing space and trailing slashes. The `https://` scheme remains. `token` loses only leading and trailing space. The request sends it unchanged in the `Authorization` header. Do not add `Bearer `.

For one command against another server, pass `--url` and `--token` in front of the subcommand. Leave the config file unchanged. With no token, the command is still sent and stderr contains:

```text
Warning: No token provided. Operations might fail if auth is required.
```

That warning alone is not a failure. Exit code 0 is success.

## Execution rules

- Subcommand results go to stdout. Queries and `config` print indented JSON. `mkdir`, `rename`, `move`, `copy`, `remove`, and `download` print one English success line.
- Failure exits 1 and writes `{"error":"..."}` to stdout. Warnings go to stderr.
- `SIGINT` and `SIGTERM` cancel the in-flight request. The HTTP timeout is 30 seconds and has no flag.
- Remote paths use `/`. Pass absolute paths to `fs`. `fs` does not turn `Movies` into `/Movies`.
- `--names` for `move`, `copy`, and `remove` is a basename in the source directory, not a full path. Repeat `--names` once per name when a name contains a comma, quote, or newline. The flag is split as CSV.
- The download URL flag is `--urls` and has no short flag. `-u` is always the server URL.
- `list` and `search` return one page. Increase `--page` until the collected rows reach `total` or the page is empty. `strm` pages on its own.
- Before delete, move, or strm overwrite, check the path with `fs list` or `fs get`. `fs remove` has no confirmation and no trash flag.

## Choose a command

| Goal | Command |
| --- | --- |
| One directory page | `fs list --path /Movies` |
| Directory entries | `fs dirs --path /Movies` |
| Metadata for one path | `fs get --path /Movies/a.mkv` |
| Keyword search | `fs search --keywords movie` |
| Create a directory | `fs mkdir --path /STRM` |
| Change a basename | `fs rename --path /Movies/a.mkv --name b.mkv` |
| Copy or move basenames | `fs copy` or `fs move` with `--src`, `--dst`, and `--names` |
| Delete basenames | `fs remove --dir /Movies --names a.mkv` |
| Enqueue an offline download | `fs download --path /Downloads --urls 'https://example.com/a' --tool aria2` |
| Generate `.strm` files | `strm`, first with `--dry-run` |

This client does not create `--dst` before `move` or `copy`. If the server rejects a missing destination, run `fs mkdir --path <dst>` and retry. `--name` on `rename` is the new filename. Changing directories is `fs move`.

There is no subcommand to upload or download file bytes, list offline tasks, or print a playback URL. Playback URLs are written only inside `.strm` files. `fs download` submits a task and does not wait.

## strm

Required flags: `--src`, `--dst`, and `--base-url`. Defaults are recursive, destination type `remote`, extensions `.mkv,.mp4,.avi,.ts`, and 8 workers.

```bash
openlist strm --src /Movies --dst /STRM --base-url https://example.com --dry-run
openlist strm --src /Movies --dst /STRM --base-url https://example.com --overwrite
```

A local destination must be an absolute path. `./strm` is cleaned to `/strm`. `~` is not expanded.

```bash
openlist strm --src /Movies --dst "$(pwd)/strm" --dst-type local --base-url https://example.com --dry-run
```

`--dry-run` still lists the server and, with `--sign`, fetches signatures. It writes no files, and on success it still prints `Generated N .strm files`. Disable recursion with `--recursive=false`. `--ext ""` matches every file that is not a directory. Without `--overwrite`, the first existing target in path order fails the whole command: `target exists: <path> (use --overwrite)`.

This client does not create parent directories for remote `.strm` files. If `put` fails because a parent is missing, run `fs mkdir` and retry. Signature, URL, and extension rules are in [reference.md](reference.md).
