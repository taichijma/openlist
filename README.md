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

Copy this string to an agent. It reads the skill and then installs, uninstalls, configures, and runs the CLI.

````text
Learn the openlist client CLI before you install, uninstall, configure, or run it. Read these files in full and follow them: .cursor/skills/openlist-cli/SKILL.md and .cursor/skills/openlist-cli/reference.md. If this repository is not checked out, clone git@github.com:0xtaichim/openlist.git and read those paths there. The skill is the procedure. The reference is the flag, JSON, and error catalog. When either file disagrees with the binary, trust `openlist <command> --help` and the packages cmd/, config/, client/, and strm/.

This program is the OpenList client, not the OpenList server. `openlist --help` must contain "OpenList CLI is a command line interface" and the commands config, fs, and strm. Do not replace a binary that fails that check.

Install a GitHub Release archive when one exists: openlist_<tag>_<os>_<arch>.tar.gz, or .zip on Windows. Platforms are linux, darwin, and windows, each with amd64 and arm64. x86_64 is amd64 and aarch64 is arm64. Verify checksums.txt from the same release. A source build in this module is `go build -o openlist .` and `openlist --version` prints `openlist version dev`. The Go module path is openlist. Do not `go install` a GitHub import path, and do not create a release tag just to install.

Uninstall only a binary whose `--help` passes the check above. Delete "${XDG_CONFIG_HOME:-$HOME/.config}/openlist" only when credentials should be removed. Leave the server and the GitHub Release in place.

Configuration order is defaults, then $XDG_CONFIG_HOME/openlist/config.yaml or ~/.config/openlist/config.yaml, then OPENLIST_URL and OPENLIST_TOKEN, then explicit --url/-u and --token/-t. Unset those two variables before `config set`, because it writes every loaded key. Send the token unchanged in the Authorization header. Do not print the token from `config list`.

Pass absolute remote paths to fs. move, copy, and remove take a directory plus basenames in --names. --urls has no short flag; -u is the server URL. list and search return one page. A local strm --dst must be absolute, because ./strm is cleaned to /strm. Run strm with --dry-run before writing. `openlist --version` works only on the root command.
````

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
