---
name: openlist-cli
description: Installs, uninstalls, configures, and operates the openlist client CLI (config, fs, strm, --version) for OpenList and AList-compatible servers. Use when installing a binary from GitHub Releases, removing the openlist binary, editing ~/.config/openlist/config.yaml, OPENLIST_URL, or OPENLIST_TOKEN, or running list, dirs, get, search, mkdir, rename, copy, move, remove, offline download, or .strm generation.
---

# OpenList CLI

`openlist` is a client for an OpenList (AList-compatible) file server. Use this file to install, uninstall, configure, and run it. Flags, JSON fields, and error strings are in [reference.md](reference.md). When help text and this skill differ, follow `openlist <command> --help` and update the skill.

## Identify the binary

```bash
openlist --help
```

Use this client when the text contains "OpenList CLI is a command line interface" and Available Commands includes `config`, `fs`, and `strm`. `openlist --help` and `openlist <command> --help` read no config file. `openlist help <command>` and `openlist completion` load the config file first.

## Install

Download the binary for this machine from https://github.com/taichijma/openlist/releases/latest

1. Read the tag of that stable release.
2. Download `openlist_<tag>_<os>_<arch>.tar.gz` and `checksums.txt` from that release. On Windows the archive is `.zip` and the binary inside is `openlist.exe`.
   - `<os>` is `linux`, `darwin`, or `windows`.
   - `<arch>` is `amd64` or `arm64`. `uname -m` value `x86_64` is `amd64`. `aarch64` is `arm64`.
   - Tag `v0.1.0` on Linux x86_64 uses these URLs:

```text
https://github.com/taichijma/openlist/releases/download/v0.1.0/openlist_v0.1.0_linux_amd64.tar.gz
https://github.com/taichijma/openlist/releases/download/v0.1.0/checksums.txt
```

3. Match the archive sha256 to its line in `checksums.txt`, then extract `openlist`.
4. When `$HOME/.local/bin/openlist` already exists, replace it when its `--help` matches this client. Otherwise install under a new name.

```bash
install -m 0755 openlist "$HOME/.local/bin/openlist"
openlist --version
openlist --help
```

`openlist --version` prints `openlist version <tag>`, for example `openlist version v0.1.0`.

Read the version with root `openlist --version` or `openlist -v`. On `config set`, `-v` is the value to store.

## Uninstall

1. Run `--help` on `$(command -v openlist)` and `"$HOME/.local/bin/openlist"`. Delete each file whose help contains "OpenList CLI is a command line interface" and `strm`. Delete the downloaded archive and `checksums.txt`.
2. To remove saved credentials as well, delete `"${XDG_CONFIG_HOME:-$HOME/.config}/openlist"` and the `OPENLIST_URL` and `OPENLIST_TOKEN` lines in shell startup files and `.env`.

## Configure

Later layers replace earlier ones: defaults, then the config file, then environment variables, then flags on this command.

| Key | Default | Environment | Flags |
| --- | --- | --- | --- |
| `url` | `http://localhost:5244` | `OPENLIST_URL` | `--url`, `-u` |
| `token` | empty | `OPENLIST_TOKEN` | `--token`, `-t` |

The file is `$XDG_CONFIG_HOME/openlist/config.yaml`, or `~/.config/openlist/config.yaml` when `XDG_CONFIG_HOME` is unset. `config set` creates the directory at mode `0700` and the file at mode `0600`. The keys are `url` and `token`, matched case-insensitively.

```bash
env -u OPENLIST_URL -u OPENLIST_TOKEN openlist config set url http://localhost:5244
env -u OPENLIST_URL -u OPENLIST_TOKEN openlist config set token '<token>'
openlist config get url
```

`config set` writes both keys from the loaded config. Clear `OPENLIST_URL` and `OPENLIST_TOKEN` before saving so the file keeps the other value already on disk. A `--url` or `--token` on that command applies to the process and stays out of the file.

`config get` and `config list` print the values in effect, including environment and flags. `config list` includes the token. Tell the user whether the token is set.

To clear the token, remove it from the environment and edit or delete the config file. `config set` accepts a non-empty value. When the YAML cannot be parsed, replace the file with valid YAML and run `config set` again.

Stored `url` values have no leading space, trailing space, or trailing slash. `https://` stays intact. The token is trimmed and sent as the `Authorization` header value.

Run one command against another server by passing the flags on that command:

```bash
openlist --url http://other:5244 --token '<token>' fs list --path /
```

An empty token still sends the request. Stderr then contains:

```text
Warning: No token provided. Operations might fail if auth is required.
```

Exit code 0 means the command succeeded.

## Run a command

- Queries and `config` print indented JSON on stdout. `mkdir`, `rename`, `move`, `copy`, `remove`, and `download` print one success line on stdout.
- A failure exits 1 and prints `{"error":"..."}` on stdout. Warnings go to stderr.
- `SIGINT` and `SIGTERM` cancel the in-flight request. The HTTP client times out after 30 seconds.
- Pass absolute remote paths, such as `/Movies`.
- `move`, `copy`, and `remove` take a directory plus basenames in `--names`. Repeat `--names` once per name. One flag also accepts comma-separated names: `--names a.txt,b.txt`.
- Pass download addresses with `--urls`. Pass the server with `--url` or `-u`.
- `list` and `search` return one page. Raise `--page` until the collected rows reach `total` or the page is empty. `strm` reads every page itself.
- Confirm a path with `fs list` or `fs get` before `fs remove`, `fs move`, or a `strm` overwrite.

## Commands

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
| Submit an offline download | `fs download --path /Downloads --urls 'https://example.com/a' --tool aria2` |
| Generate `.strm` files | `strm`, first with `--dry-run` |

`rename --name` is the new filename. Move into another directory with `fs move`. When `move` or `copy` fails because the destination is missing, run `fs mkdir --path <dst>` and retry.

`strm` writes each playback URL into a `.strm` file. `fs download` submits the task and prints `Download task added successfully`.

## strm

Required flags are `--src`, `--dst`, and `--base-url`. Defaults are recursive walk, destination type `remote`, extensions `.mkv,.mp4,.avi,.ts`, and 8 workers.

```bash
openlist strm --src /Movies --dst /STRM --base-url https://example.com --dry-run
openlist strm --src /Movies --dst /STRM --base-url https://example.com --overwrite
```

Pass an absolute path for a local destination. `./strm` is cleaned to `/strm`.

```bash
openlist strm --src /Movies --dst "$(pwd)/strm" --dst-type local --base-url https://example.com --dry-run
```

`--dry-run` lists the server and, with `--sign`, fetches signatures. It prints each action and `Generated N .strm files` without writing files. Limit the walk to the source directory with `--recursive=false`. `--ext ""` includes every file. With the default overwrite setting, the first existing target in path order stops the command: `target exists: <path> (use --overwrite)`.

Create a missing remote parent with `fs mkdir` before writing remote `.strm` files. Signature, URL, and extension rules are in [reference.md](reference.md).
