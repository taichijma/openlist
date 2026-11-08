# openlist

CLI for [OpenList](https://github.com/OpenListTeam/OpenList) (AList-compatible) file servers.

## Features

- Manage files remotely: list, search, mkdir, rename, copy, move, remove
- Offline download tasks
- Generate `.strm` files (local or remote) with concurrent directory walking
- XDG config (`~/.config/openlist/config.yaml`) plus `OPENLIST_*` env and flags

## Install

```bash
git clone git@github.com:0xtaichim/openlist.git
cd openlist
go build -o openlist .
```

Requires Go 1.23+.

## Configuration

Priority (low → high): defaults → config file → environment → flags.

```bash
openlist config set url http://localhost:5244
openlist config set token <your-token>
openlist config list
```

Environment:

- `OPENLIST_URL`
- `OPENLIST_TOKEN`
- `XDG_CONFIG_HOME` (config directory root)

Flags on every command: `--url` / `-u`, `--token` / `-t`.

## Examples

```bash
openlist fs list --path /
openlist fs get --path /Movies
openlist strm --src /Movies --dst /STRM --base-url https://example.com
openlist strm --src /Movies --dst ./strm --dst-type local --base-url https://example.com --dry-run
```

## Agents

```text
Download and install the openlist-cli skill from https://github.com/taichijma/openlist/tree/main/skills/openlist-cli.
```

## Release

Push a semantic version tag to publish a GitHub Release. The workflow tests
this module, attaches Linux, macOS, and Windows binaries, and writes the
release notes from pull requests merged since the previous tag.

```bash
git tag v0.1.0
git push origin v0.1.0
```

`openlist --version` prints that tag for a release build, and `dev` for a
local build. A tag such as `v0.1.0-rc.1` is published as a pre-release.
Re-running the workflow replaces the binaries and keeps notes that are
already written.

Pull requests are grouped with labels. A title that follows
[Conventional Commits](https://www.conventionalcommits.org/) is labeled
when the pull request is opened or edited:

| Pull request title | Release notes section |
| --- | --- |
| `feat:` | Features |
| `fix:` | Bug fixes |
| `docs:` | Documentation |
| `feat!:`, `fix!:`, or a `BREAKING CHANGE:` footer | Breaking changes |

Other merged pull requests are listed under Other changes. Add the
`ignore-for-release` label to leave one out.

## License

MIT
