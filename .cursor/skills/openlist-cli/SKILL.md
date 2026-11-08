---
name: openlist-cli
description: Installs, uninstalls, configures, and operates the openlist client CLI (config, fs, strm, --version) for OpenList and AList-compatible servers. Use when installing a GitHub Release archive or a source build, removing the openlist binary, editing ~/.config/openlist/config.yaml, OPENLIST_URL, or OPENLIST_TOKEN, or running list, dirs, get, search, mkdir, rename, copy, move, remove, offline download, or .strm generation.
---

# OpenList CLI

本仓库的 `openlist` 是 OpenList（AList 兼容）文件服务器的客户端。它不启动、不安装、不管理服务器进程。

命令与源码不一致时，以 `openlist <command> --help` 和 `cmd/`、`config/`、`client/`、`strm/` 为准，并更新本技能。字段、错误原文和示例见 [reference.md](reference.md)。

## 确认二进制

先确认将要执行的文件是这个客户端，而不是同名的 OpenList 服务器。

```bash
openlist --help
```

正文要包含 “OpenList CLI is a command line interface”，并且 Available Commands 里有 `config`、`fs`、`strm`。`openlist fs --help` 只列出文件子命令，不能用来辨认二进制。帮助不符的同名文件是别的程序，不要覆盖，也不要把它当成这个客户端。

配置文件损坏时，`openlist --help` 和 `openlist <command> --help` 仍可用。`openlist help <command>` 和 `openlist completion` 会先读配置，文件损坏时失败。

## 安装

已有 GitHub Release 时，安装对应平台的归档。没有发布，或需要当前提交时，在已有检出里构建。不要为了安装去打标签或触发发布。

发布资产名是 `openlist_<tag>_<os>_<arch>.tar.gz`，Windows 是同名 `.zip`。`<tag>` 带 `v`，例如 `openlist_v0.1.0_linux_amd64.tar.gz`。包内文件名是 `openlist`，Windows 是 `openlist.exe`。平台只有 `linux`、`darwin`、`windows` 与 `amd64`、`arm64` 的组合。`uname -m` 的 `x86_64` 对应 `amd64`，`aarch64` 对应 `arm64`。

下载归档和同一次发布的 `checksums.txt`，核对 sha256 后再解压。目标路径上已经有文件时，先执行它的 `--help`；帮助不符时换一个文件名。

```bash
install -m 0755 openlist "$HOME/.local/bin/openlist"
openlist --version
openlist --help
```

发布包的 `--version` 打印该 tag。源码构建打印 `dev`。

已在本仓库检出、需要当前提交时直接构建，不要再克隆。

```bash
go version
go build -o openlist .
./openlist --version
./openlist --help
```

需要 Go 1.23 或更新。`go.mod` 的 `toolchain` 为 `go1.24.12`，默认的 `GOTOOLCHAIN=auto` 会在需要时下载该工具链。首次构建需要能拉取模块。

`go.mod` 的 module 路径是 `openlist`。不要执行 `go install github.com/.../openlist@latest`。需要装到 `PATH` 时，在仓库根目录执行 `go install .`，二进制落在 `$GOBIN`，未设置时为 `$(go env GOPATH)/bin/openlist`。这样装上的也是 `dev` 版本。`go install` 不会修改 `PATH`。

要放到 `PATH` 上、又不使用 `go install` 时：

```bash
install -m 0755 ./openlist "$HOME/.local/bin/openlist"
```

一次性调试用 `go run . fs list --path /`，参数写在包路径之后。`go run` 同样打印 `dev`。

版本标志只在根命令上：`openlist --version` 或 `openlist -v`。输出是 `openlist version <版本>`，退出码 0，而且不读取配置文件。子命令不接受 `--version`。`config set -v` 是要写入的值，不是版本。

## 卸载

没有 `uninstall` 子命令。卸载客户端时不要删除服务器、其数据目录或容器。

1. 用 `command -v openlist` 和仓库内 `./openlist` 找到候选文件。对每个候选执行 `--help`，只有同时出现 “OpenList CLI is a command line interface” 和 `strm` 时才删除。`go install` 的副本在 `$GOBIN`，未设置时为 `$(go env GOPATH)/bin/openlist`。发布包解压出来的副本、下载的归档和 `checksums.txt` 也一并删除。不要删除 GitHub Release 本身。
2. 用户要求连同凭据一起卸载时，删除配置目录 `"${XDG_CONFIG_HOME:-$HOME/.config}/openlist"`。其中 `config.yaml` 含 token，权限 `0600`。只要求卸二进制时保留该目录。
3. 凭据一并卸载时，从 shell 启动文件和仓库 `.env` 中删掉 `OPENLIST_URL`、`OPENLIST_TOKEN` 这两行，不要改写文件里的其他内容。补全脚本只有用户曾经写入 shell 启动文件时才需要移除。

卸完后，原路径上的 `--help` 不应再出现这个客户端。

## 配置

生效顺序：默认值，然后配置文件，然后环境变量，然后本次显式传入的标志。后一层覆盖前一层。

| 键 | 默认 | 环境变量 | 标志 |
| --- | --- | --- | --- |
| `url` | `http://localhost:5244` | `OPENLIST_URL` | `--url`、`-u` |
| `token` | 空 | `OPENLIST_TOKEN` | `--token`、`-t` |

配置文件：`$XDG_CONFIG_HOME/openlist/config.yaml`，未设置 `XDG_CONFIG_HOME` 时为 `~/.config/openlist/config.yaml`。`config set` 会创建目录 `0700`、文件 `0600`。键只有 `url` 和 `token`，大小写不敏感。

```bash
env -u OPENLIST_URL -u OPENLIST_TOKEN openlist config set url http://localhost:5244
env -u OPENLIST_URL -u OPENLIST_TOKEN openlist config set token '<token>'
openlist config get url
```

`config set` 会把 `Load()` 的结果整份写回。环境变量里的 `url` 或 `token` 会一起进文件，即使这次只改另一个键。写文件前用 `env -u OPENLIST_URL -u OPENLIST_TOKEN`。`--url` 和 `--token` 不会被 `config set` 写进文件。

`config get` 和 `config list` 显示的是本次生效值，包含环境和标志。`config list` 的 stdout 含明文 token。向用户汇报时只说明 token 是否非空，不粘贴 token。

空字符串不能作为 `config set` 的值。要清空 token，先卸掉相关环境变量，再改或删除配置文件。`config set` 读不到损坏的 YAML，不能用它修复。把损坏文件移走或改成合法 YAML 后重新 `config set`。`--url` 不能跳过损坏的配置文件。

`url` 会去掉首尾空白和末尾的 `/`，`https://` 会保留。token 只做首尾去空白，请求时原样放进 `Authorization` 头，不要加 `Bearer `。

单次命令需要另一台服务器时，在命令前加 `--url` 和 `--token`，不要为了一次调用改配置文件。未提供 token 时命令仍会发送，stderr 出现：

```text
Warning: No token provided. Operations might fail if auth is required.
```

这行警告本身不是失败。退出码为 0 才算成功。

## 执行约定

- 子命令的业务输出在 stdout。查询和 `config` 是缩进 JSON。`mkdir`、`rename`、`move`、`copy`、`remove`、`download` 是一行英文成功句。
- 失败时退出码为 1，stdout 为 `{"error":"..."}`。警告在 stderr。
- `SIGINT` 和 `SIGTERM` 会取消正在进行的请求。HTTP 超时固定 30 秒，没有对应标志。
- 远程路径使用 `/`，传给 `fs` 时写绝对路径。`fs` 不会把 `Movies` 改成 `/Movies`。
- `move`、`copy`、`remove` 的 `--names` 是源目录下的基名，不是完整路径。名字含逗号、引号或换行时，每个名字单独一个 `--names`，因为该标志按 CSV 拆分。
- `download` 的地址标志是 `--urls`，没有短标志。`-u` 永远是服务器 URL。
- `list` 和 `search` 只返回一页。`total` 大于本页 `content` 时递增 `--page`，直到收齐或本页为空。`strm` 自己翻页，不要在外面按页调用。
- 删除、移动、覆盖 strm 之前，先用 `fs list` 或 `fs get` 核对路径。`fs remove` 没有确认，也没有回收站标志。

## 选择命令

| 目的 | 命令 |
| --- | --- |
| 看目录一页 | `fs list --path /Movies` |
| 看目录项 | `fs dirs --path /Movies` |
| 看一个路径的元数据 | `fs get --path /Movies/a.mkv` |
| 按关键字搜索 | `fs search --keywords movie` |
| 建目录 | `fs mkdir --path /STRM` |
| 改基名 | `fs rename --path /Movies/a.mkv --name b.mkv` |
| 复制或移动若干基名 | `fs copy` 或 `fs move` 的 `--src`、`--dst`、`--names` |
| 删除若干基名 | `fs remove --dir /Movies --names a.mkv` |
| 提交离线下载 | `fs download --path /Downloads --urls 'https://example.com/a' --tool aria2` |
| 生成 `.strm` | `strm`，先 `--dry-run` |

`move` 和 `copy` 之前，本客户端不会创建 `--dst`。若因此失败，再执行 `fs mkdir --path <dst>` 后重试。`rename` 的 `--name` 只写新文件名；换目录用 `fs move`。

没有上传、下载文件内容、列出离线任务或直接打印播放地址的子命令。播放地址只由 `strm` 写入 `.strm` 文件。`fs download` 只向服务器提交任务，不等待完成。

## strm

必填：`--src`、`--dst`、`--base-url`。默认递归、目标类型 `remote`、扩展名 `.mkv,.mp4,.avi,.ts`、8 个并发 worker。

```bash
openlist strm --src /Movies --dst /STRM --base-url https://example.com --dry-run
openlist strm --src /Movies --dst /STRM --base-url https://example.com --overwrite
```

本地目标必须是绝对路径。`./strm` 会被收成 `/strm`，`~` 不会展开。

```bash
openlist strm --src /Movies --dst "$(pwd)/strm" --dst-type local --base-url https://example.com --dry-run
```

`--dry-run` 仍会列出服务器；加了 `--sign` 时还会取签名。它不写文件，但成功时仍打印 `Generated N .strm files`。关掉递归用 `--recursive=false`。`--ext ""` 会匹配所有非目录文件。未加 `--overwrite` 时，按路径排序后的第一个已存在目标会使整个命令失败：`target exists: <path> (use --overwrite)`。

本客户端不会为远程 `.strm` 创建父目录。`put` 因父目录不存在而失败时，先 `fs mkdir` 再重试。签名、URL 形态和扩展名规则见 [reference.md](reference.md)。
