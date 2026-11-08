# openlist CLI reference

The procedure is in [SKILL.md](SKILL.md). Flags, paths, and output below match the current source.

Global flags may appear before or after the subcommand. The `--url` default shown in help is only the flag default. When the flag is omitted, the config file and environment win. A flag overrides the environment only when it is present on the command line.

Identify the binary with `openlist --help`. The text starts with "OpenList CLI is a command line interface", and Available Commands includes `completion`, `config`, `fs`, and `strm`. `openlist fs --help` lists only `fs` subcommands.

## version

There is no `version` subcommand. Root `--version` and `-v` print to stdout:

```text
openlist version dev
```

`go build`, `go install .`, and `go run` keep the literal `dev`. The release workflow injects the tag with `-ldflags "-X openlist/cmd.Version=<tag>"`, for example `openlist version v0.1.0`.

The flag is handled before config is read, so it succeeds when the config file is invalid and exits 0. It is not a persistent flag. `openlist fs --version` fails with `unknown flag: --version`. On `config set`, `-v` belongs to that subcommand.

## config

```text
openlist config get [key]
openlist config set [key] [value]
openlist config list
```

`get` and `set` also accept `--key` / `-k`. The `set` value is a positional argument or `--value` / `-v`.

Success:

```json
{ "message": "ok" }
```

`get url` prints `{"url":"..."}`. `get token` prints `{"token":"..."}`. `list` prints `url` and `token`. JSON map keys are alphabetical, and the token is plaintext.

Error strings:

- Missing key: `key is required`
- Missing key or value: `key and value are required`
- Unknown key: `unknown key: <key>`

The written YAML contains only `url` and `token`. `http://example:5244/` is stored as `http://example:5244`.

## fs behavior

Every `fs` subcommand is a `POST` with `Content-Type: application/json` and `User-Agent: openlist-cli`. A non-empty token sets `Authorization: <token>`. Remote `.strm` upload is the only `PUT /api/fs/put`.

HTTP status 400 or higher: `api request failed with status <code>: <body>`. The body is kept up to 8 KiB. HTTP success with an envelope `code` other than 200: `api error: <message>`, without the numeric code. Transport failure: `failed to send request: ...`.

Query commands print the envelope `data` as indented JSON on stdout. Mutation commands print one fixed English sentence and a trailing newline.

When a `list` or `dirs` entry has an empty `path` and a non-empty `name`, the client fills `<directory>/<name>`.

### fs list

`POST /api/fs/list`

| Flag | Short | Default | Request field |
| --- | --- | --- | --- |
| `--path` | `-p` | `/` | `path` |
| `--password` | | omitted when empty | `password` |
| `--refresh` | | omitted when false | `refresh` |
| `--page` | | `1` | `page` |
| `--per-page` | | `30` | `per_page` |

Stdout is one directory page:

```json
{
  "content": [],
  "total": 0,
  "readme": "",
  "header": "",
  "write": false,
  "provider": ""
}
```

Each `content` object has `id`, `path`, `name`, `size`, `is_dir`, `modified`, `created`, `sign`, `thumb`, `type`, `hashinfo`, and `mount_details`. `mount_details` has `driver_name`, `total_space`, and `free_space`. `modified` and `created` are JSON time strings. The client re-encodes the struct, so zero values omitted by the server are still printed.

`--password` is for a directory that requires a password. `--refresh` sends `refresh: true`. Its help text is "Force refresh".

### fs dirs

`POST /api/fs/dirs`

| Flag | Short | Default | Request field |
| --- | --- | --- | --- |
| `--path` | `-p` | `/` | `path` |
| `--password` | | omitted when empty | `password` |
| `--force-root` | | omitted when false | `force_root` |

Stdout is a JSON array of `{"name":"...","path":"..."}`. This is the server directory endpoint. This client does not walk the tree itself.

### fs get

`POST /api/fs/get`. `--path` / `-p` is required. `--password` is optional. Stdout is one file object with the same fields as a `list` content entry.

### fs search

`POST /api/fs/search`

| Flag | Short | Default | Request field |
| --- | --- | --- | --- |
| `--parent` | `-p` | `/` | `parent` |
| `--keywords` | `-k` | required | `keywords` |
| `--scope` | | `0`, and `0` is omitted from JSON | `scope` |
| `--page` | | `1` | `page` |
| `--per-page` | | `30` | `per_page` |

Stdout is `{"content":[...],"total":N}`. This client does not define what `scope` means. A non-zero value is forwarded as-is. When search is disabled on the server, the failure text is the server `message`.

### fs mkdir

`POST /api/fs/mkdir`. `--path` / `-p` is required. Success stdout:

```text
Directory created successfully
```

The client does not create missing parents one level at a time.

### fs rename

`POST /api/fs/rename`. `--path` / `-p` is the existing full path. `--name` / `-n` is the new basename. Success stdout:

```text
Renamed successfully
```

### fs copy and fs move

`POST /api/fs/copy` or `POST /api/fs/move`.

| Flag | Short | Request field |
| --- | --- | --- |
| `--src` | `-s` | `src_dir` |
| `--dst` | `-d` | `dst_dir` |
| `--names` | `-n` | `names` |

All three flags are required. `--src` and `--dst` are directories. `--names` lists basenames in the source directory. Repeat the flag, or pass several comma-free names in one value: `--names a.txt,b.txt`.

Success stdout is `Copied successfully` or `Moved successfully`.

### fs remove

`POST /api/fs/remove`. `--dir` / `-d` is the directory. `--names` / `-n` lists basenames in it, with the same splitting rules as copy. A directory basename is allowed. There is no recursive flag. Success stdout:

```text
Removed successfully
```

### fs download

`POST /api/fs/add_offline_download`.

| Flag | Short | Default | Request field |
| --- | --- | --- | --- |
| `--path` | `-p` | required | `path` |
| `--urls` | none | required | `urls` |
| `--tool` | | `aria2` | `tool` |

`--urls` splits like `--names`. Repeat the flag when a URL contains a comma. `--tool` is sent unchanged. Its help text is "aria2, qbittorrent, etc." The name must be a tool configured on the server.

Success stdout:

```text
Download task added successfully
```

There is no command to list or cancel tasks.

## strm

```text
openlist strm --src <remote-dir> --dst <dest-dir> --base-url <direct-link-prefix> [flags]
```

| Flag | Short | Default | Role |
| --- | --- | --- | --- |
| `--src` | `-s` | required | OpenList source directory |
| `--dst` | `-d` | required | Destination directory |
| `--dst-type` | | `remote` | `remote` or `local` |
| `--base-url` | | required | Direct-link prefix; trailing `/` is removed |
| `--ext` | | `.mkv,.mp4,.avi,.ts` | Comma-separated; case-insensitive; a leading dot is optional |
| `--recursive` | | true | `--recursive=false` scans only the source directory |
| `--overwrite` | | false | Replace an existing `.strm` |
| `--dry-run` | | false | Print actions and write nothing |
| `--sign` | | false | Append a `sign` query parameter |
| `--concurrency` | | `8` | Listing and sign-fetch workers; `0` or less still uses 8 |

An invalid destination type produces `invalid --dst-type "<value>" (expected remote or local)`.

Source and remote destination paths are cleaned to absolute remote paths: `Movies` becomes `/Movies`. A local `--dst` uses the same cleaner, so pass an absolute local path. `./strm` becomes `/strm`. `~/strm` becomes `/~/strm`.

Extension mapping: `/Movies/A/B.mkv` with source `/Movies` and destination `/STRM` becomes `/STRM/A/B.strm`. An empty `--ext` matches every file. Directories never become strm files. Extensions outside the filter are skipped.

The walk requests 200 entries per page, deduplicates paths, and processes results in ascending path order. The first error stops the command. Later files are not written.

A direct link is `<base-url>/d` plus the path with each segment percent-encoded. `/A B/测试.mkv` encodes as `/A%20B/%E6%B5%8B%E8%AF%95.mkv`. A signature adds `?sign=` with the signature query-encoded, so `sig+n` becomes `sig%2Bn`.

`--sign` uses `sign` from `list` when it is present. Otherwise it calls `POST /api/fs/get`. An empty final signature leaves the link without a query string.

File content is the direct link plus one newline. Remote write is `PUT /api/fs/put` with `Content-Type: application/octet-stream`. The `File-Path` header is `PathEscape` of the whole target path. This client does not create the remote parent. Without overwrite, a successful `get` is treated as "already exists" and fails with `target exists: <path> (use --overwrite)`. A failed `get` continues to `put`, so an auth error appears again on `put`.

Local writes use the operating-system path. Parent directories are mode `0755` and files are mode `0644`. An existing file without overwrite returns the same `target exists` error.

Stdout:

```text
[dry-run] /Movies/movie.mkv -> /STRM/movie.strm
Generated 1 .strm files
```

A real write prints only the final `Generated N .strm files`. `N` includes files counted by dry-run. Zero matches still print `Generated 0 .strm files`.

## Failure output

`main` encodes the error as indented JSON on stdout and exits 1:

```json
{
  "error": "required flag(s) \"path\" not set"
}
```

When the config file exists but is invalid YAML, every real subcommand fails. Flags cannot bypass it:

```text
failed to load config: failed to read config file: ...
```

A missing file is normal. Defaults, environment variables, and flags are then used.

## End-to-end sequence

Replace `<token>` with the token supplied for the task. This assumes the binary is `./openlist` in the repo and the shell has neither `OPENLIST_URL` nor `OPENLIST_TOKEN`.

```bash
go build -o openlist .
env -u OPENLIST_URL -u OPENLIST_TOKEN ./openlist config set url http://127.0.0.1:5244
env -u OPENLIST_URL -u OPENLIST_TOKEN ./openlist config set token '<token>'
./openlist config get url
./openlist fs list --path /
./openlist fs mkdir --path /STRM
./openlist fs rename --path /Movies/old.mkv --name new.mkv
./openlist fs copy --src /Movies --dst /Backup --names new.mkv
./openlist fs move --src /Backup --dst /Archive --names new.mkv
./openlist fs search --parent /Movies --keywords new
./openlist fs download --path /Downloads --urls 'https://example.com/a.mkv'
./openlist strm --src /Movies --dst /STRM --base-url https://example.com --dry-run
./openlist strm --src /Movies --dst /STRM --base-url https://example.com --overwrite
./openlist fs remove --dir /Archive --names new.mkv
```

Point one command at another server:

```bash
./openlist --url http://other:5244 --token '<token>' fs get --path /Movies
```

Release sha256 lines are in that release's `checksums.txt`, produced by `sha256sum`. Assets cover `linux`, `darwin`, and `windows`, each with `amd64` and `arm64`. `dist/` in the repo is local release-script output, is gitignored, and is not an install step.

The README clone commands for a new checkout are:

```bash
git clone git@github.com:0xtaichim/openlist.git
cd openlist
go build -o openlist .
```

Use the clone URL from this repository's README. The module path remains `openlist`. Build inside the checkout.
