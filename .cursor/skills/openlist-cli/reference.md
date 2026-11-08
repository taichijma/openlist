# openlist CLI 参考

主流程在 [SKILL.md](SKILL.md)。下文的标志、路径和输出与当前源码一致。

全局标志可放在子命令前或后。帮助里的 `--url` 默认值只是标志默认值；没有显式传入时，配置文件和环境变量优先。只有标志出现在命令行上才覆盖环境变量。

身份检查用 `openlist --help`。正文以 “OpenList CLI is a command line interface” 开头，Available Commands 包含 `completion`、`config`、`fs`、`strm`。`openlist fs --help` 只列出 `fs` 的子命令。

## version

没有 `version` 子命令。根命令上的 `--version` 和 `-v` 打印到 stdout：

```text
openlist version dev
```

本地 `go build`、`go install .` 和 `go run` 的版本字面量是 `dev`。发布工作流用 `-ldflags "-X openlist/cmd.Version=<tag>"` 写入标签，例如 `openlist version v0.1.0`。

该标志在读取配置之前处理，配置文件损坏时仍然成功，退出码 0。它不是持久标志。`openlist fs --version` 失败，错误原文是 `unknown flag: --version`。`config set` 的 `-v` 只属于那个子命令。

## config

```text
openlist config get [key]
openlist config set [key] [value]
openlist config list
```

`get` 和 `set` 也接受 `--key` / `-k`。`set` 的值用位置参数，或 `--value` / `-v`。

成功：

```json
{ "message": "ok" }
```

`get url` 输出 `{"url":"..."}`。`get token` 输出 `{"token":"..."}`。`list` 输出 `url` 和 `token`，JSON 键按字母序，token 为明文。

错误原文：

- 缺少键：`key is required`
- 缺少键或值：`key and value are required`
- 未知键：`unknown key: <key>`

写入的 YAML 只有 `url` 和 `token`。`http://example:5244/` 存成 `http://example:5244`。

## fs 公共行为

`fs` 的每个子命令都是 `POST`，`Content-Type: application/json`，`User-Agent: openlist-cli`。token 非空时设置 `Authorization: <token>`。远程 `.strm` 才使用 `PUT /api/fs/put`。

HTTP 状态码大于等于 400：`api request failed with status <code>: <body>`，响应体最多保留 8 KiB。HTTP 成功但信封 `code` 不是 200：`api error: <message>`，不包含数字 code。传输失败：`failed to send request: ...`。

查询命令把信封里的 `data` 缩进打印到 stdout。变更命令打印固定英文句子，末尾有换行。

`list` 和 `dirs` 的条目若缺少 `path` 但有 `name`，客户端会补成 `<目录>/<name>`。

### fs list

`POST /api/fs/list`

| 标志 | 短标志 | 默认 | 请求字段 |
| --- | --- | --- | --- |
| `--path` | `-p` | `/` | `path` |
| `--password` | | 空则省略 | `password` |
| `--refresh` | | false 则省略 | `refresh` |
| `--page` | | `1` | `page` |
| `--per-page` | | `30` | `per_page` |

stdout 是一页目录：

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

`content` 里每个对象的字段：`id`、`path`、`name`、`size`、`is_dir`、`modified`、`created`、`sign`、`thumb`、`type`、`hashinfo`、`mount_details`。`mount_details` 含 `driver_name`、`total_space`、`free_space`。`modified` 和 `created` 是 JSON 时间字符串。客户端按结构体重新编码，服务器省略的零值仍会打印出来。

`--password` 用于服务器要求密码的目录。`--refresh` 发送 `refresh: true`，帮助文本是 “Force refresh”。

### fs dirs

`POST /api/fs/dirs`

| 标志 | 短标志 | 默认 | 请求字段 |
| --- | --- | --- | --- |
| `--path` | `-p` | `/` | `path` |
| `--password` | | 空则省略 | `password` |
| `--force-root` | | false 则省略 | `force_root` |

stdout 是 JSON 数组，元素为 `{"name":"...","path":"..."}`。这是服务器的目录项接口，不是本客户端自己的递归遍历。

### fs get

`POST /api/fs/get`。`--path` / `-p` 必填。`--password` 可选。stdout 是单个文件对象，字段与 `list` 的 `content` 元素相同。

### fs search

`POST /api/fs/search`

| 标志 | 短标志 | 默认 | 请求字段 |
| --- | --- | --- | --- |
| `--parent` | `-p` | `/` | `parent` |
| `--keywords` | `-k` | 必填 | `keywords` |
| `--scope` | | `0`，且 `0` 不写入 JSON | `scope` |
| `--page` | | `1` | `page` |
| `--per-page` | | `30` | `per_page` |

stdout 为 `{"content":[...],"total":N}`。本客户端不解释 `scope` 的业务含义，非 0 时原样交给服务器。服务器未开启搜索时，失败信息来自服务器的 `message`。

### fs mkdir

`POST /api/fs/mkdir`。`--path` / `-p` 必填。成功 stdout：

```text
Directory created successfully
```

客户端不逐级创建父目录。

### fs rename

`POST /api/fs/rename`。`--path` / `-p` 是现有完整路径，`--name` / `-n` 是新基名。成功 stdout：

```text
Renamed successfully
```

### fs copy 与 fs move

`POST /api/fs/copy` 或 `POST /api/fs/move`。

| 标志 | 短标志 | 请求字段 |
| --- | --- | --- |
| `--src` | `-s` | `src_dir` |
| `--dst` | `-d` | `dst_dir` |
| `--names` | `-n` | `names` |

三个标志都必填。`--src` 和 `--dst` 是目录。`--names` 是该源目录中的基名，可重复传入，或用逗号一次传入多个不含逗号的名字：`--names a.txt,b.txt`。

成功 stdout 分别为 `Copied successfully` 和 `Moved successfully`。

### fs remove

`POST /api/fs/remove`。`--dir` / `-d` 是目录，`--names` / `-n` 是其中的基名，规则与 copy 相同。可以删除目录名；没有单独的递归标志。成功 stdout：

```text
Removed successfully
```

### fs download

`POST /api/fs/add_offline_download`。

| 标志 | 短标志 | 默认 | 请求字段 |
| --- | --- | --- | --- |
| `--path` | `-p` | 必填 | `path` |
| `--urls` | 无 | 必填 | `urls` |
| `--tool` | | `aria2` | `tool` |

`--urls` 的拆分规则与 `--names` 相同。URL 含逗号时重复该标志。`--tool` 原样发送，帮助文本为 “aria2, qbittorrent, etc.”；具体名称必须是服务器已配置的离线下载工具。

成功 stdout：

```text
Download task added successfully
```

没有查询或取消任务的命令。

## strm

```text
openlist strm --src <远程目录> --dst <目标目录> --base-url <直链前缀> [flags]
```

| 标志 | 短标志 | 默认 | 作用 |
| --- | --- | --- | --- |
| `--src` | `-s` | 必填 | OpenList 源目录 |
| `--dst` | `-d` | 必填 | 目标目录 |
| `--dst-type` | | `remote` | `remote` 或 `local` |
| `--base-url` | | 必填 | 直链前缀，末尾 `/` 会去掉 |
| `--ext` | | `.mkv,.mp4,.avi,.ts` | 逗号分隔，大小写不敏感，点可省略 |
| `--recursive` | | true | `--recursive=false` 只扫源目录本层 |
| `--overwrite` | | false | 覆盖已有 `.strm` |
| `--dry-run` | | false | 列出动作，不写文件 |
| `--sign` | | false | 直链追加 `sign` 查询参数 |
| `--concurrency` | | `8` | 列目录和补签名的并行数；小于等于 0 时仍用 8 |

非法目标类型：`invalid --dst-type "<value>" (expected remote or local)`。

源路径和远程目标会收成绝对远程路径：`Movies` 变成 `/Movies`。本地 `--dst` 也走同一清洗，所以必须传入绝对本地路径。`./strm` 会变成 `/strm`，`~/strm` 会变成 `/~/strm`。

扩展名映射：`/Movies/A/B.mkv`、源 `/Movies`、目标 `/STRM` 得到 `/STRM/A/B.strm`。空的 `--ext` 匹配所有文件。目录始终不生成 strm。默认扩展名之外的文件被跳过。

遍历每页 200 条，按路径去重，结果按路径升序处理。遇到错误即停止，不继续写后面的文件。

直链形态：`<base-url>/d` 加上逐段百分号编码的路径。`/A B/测试.mkv` 编码为 `/A%20B/%E6%B5%8B%E8%AF%95.mkv`。有签名时追加 `?sign=`，签名再做查询编码，`sig+n` 变成 `sig%2Bn`。

`--sign` 优先使用 `list` 返回的 `sign`。缺失时再 `POST /api/fs/get` 取 `sign`。最终签名仍为空时，直链不带查询参数。

文件内容是直链加一个换行。远程写入是 `PUT /api/fs/put`，`Content-Type: application/octet-stream`，`File-Path` 头为整条目标路径的 `PathEscape`。远程父目录不会被此客户端创建。未覆盖时，`get` 成功视为已存在并失败：`target exists: <path> (use --overwrite)`。`get` 失败则继续 `put`，因此认证错误会在 `put` 上再次出现。

本地写入使用操作系统路径，父目录权限 `0755`，文件权限 `0644`。已存在且未覆盖时同样报 `target exists`。

stdout：

```text
[dry-run] /Movies/movie.mkv -> /STRM/movie.strm
Generated 1 .strm files
```

正式写入只有最后的 `Generated N .strm files`。`N` 包含 dry-run 计到的文件，0 个匹配也会打印 `Generated 0 .strm files`。

## 失败输出

`main` 把错误编成缩进 JSON 写到 stdout，然后以状态码 1 退出：

```json
{
  "error": "required flag(s) \"path\" not set"
}
```

配置文件存在但 YAML 无法解析时，任何真正的子命令都失败，标志无法绕过：

```text
failed to load config: failed to read config file: ...
```

文件不存在是正常状态，随后使用默认值、环境变量和标志。

## 端到端序列

把 `<token>` 换成用户提供的 token。下面假设二进制是仓库内的 `./openlist`，且当前 shell 没有 `OPENLIST_URL` 或 `OPENLIST_TOKEN`。

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

临时指向另一台服务器：

```bash
./openlist --url http://other:5244 --token '<token>' fs get --path /Movies
```

发布归档的 sha256 在同一次 Release 的 `checksums.txt`，由 `sha256sum` 生成。资产覆盖 `linux`、`darwin`、`windows` 与 `amd64`、`arm64`。仓库里的 `dist/` 是本地发布脚本的输出目录，已在 `.gitignore` 中，不是安装步骤的一部分。

需要新的源码检出时，README 中的克隆命令是：

```bash
git clone git@github.com:0xtaichim/openlist.git
cd openlist
go build -o openlist .
```

克隆地址以该仓库 README 为准。module 路径仍是 `openlist`，构建始终在检出目录内进行。
