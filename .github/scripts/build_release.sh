#!/usr/bin/env bash
# Cross-compile openlist and write dist/ archives plus checksums.txt.
set -euo pipefail

version="${1:-${GITHUB_REF_NAME:-}}"
if [[ ! "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "usage: build_release.sh vX.Y.Z" >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
out="${root}/dist"
rm -rf "$out"
mkdir -p "$out"

ldflags="-s -w -X openlist/cmd.Version=${version}"
platforms=(
  linux/amd64
  linux/arm64
  darwin/amd64
  darwin/arm64
  windows/amd64
  windows/arm64
)

stage=""
cleanup() {
  if [[ -n "$stage" && -d "$stage" ]]; then
    rm -rf "$stage"
  fi
}
trap cleanup EXIT

for platform in "${platforms[@]}"; do
  goos="${platform%%/*}"
  goarch="${platform##*/}"
  bin="openlist"
  if [[ "$goos" == "windows" ]]; then
    bin="openlist.exe"
  fi
  stage="$(mktemp -d)"
  CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
    go build -trimpath -ldflags "$ldflags" -o "${stage}/${bin}" .
  archive="openlist_${version}_${goos}_${goarch}"
  if [[ "$goos" == "windows" ]]; then
    (cd "$stage" && zip -q -X "${out}/${archive}.zip" "$bin")
  else
    tar -C "$stage" -czf "${out}/${archive}.tar.gz" "$bin"
  fi
  rm -rf "$stage"
  stage=""
done

(
  cd "$out"
  sha256sum openlist_* > checksums.txt
)
