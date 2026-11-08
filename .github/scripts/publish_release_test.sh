#!/usr/bin/env bash
# Exercise publish_release.sh with a fake gh binary.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
publisher="${root}/publish_release.sh"
failures=0

assert_log() {
  local log="$1"
  local want="$2"
  if ! grep -Fqx -- "$want" "$log"; then
    echo "missing log line: $want" >&2
    echo "actual:" >&2
    cat "$log" >&2
    failures=$((failures + 1))
  fi
}

assert_absent() {
  local log="$1"
  local needle="$2"
  if grep -F -- "$needle" "$log" >/dev/null; then
    echo "unexpected log text: $needle" >&2
    cat "$log" >&2
    failures=$((failures + 1))
  fi
}

run_case() {
  local name="$1"
  local tag="$2"
  local exists="$3"
  local body="$4"
  local work
  work="$(mktemp -d)"
  local bin="${work}/bin"
  mkdir -p "$bin" "${work}/dist"
  echo "asset" >"${work}/dist/openlist_${tag}_linux_amd64.tar.gz"
  cat >"${bin}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${GH_LOG}"
if [[ "$1" == "release" && "$2" == "view" ]]; then
  if [[ "${RELEASE_EXISTS}" == "1" ]]; then
    printf '%s' "${RELEASE_BODY}"
    exit 0
  fi
  echo "release not found" >&2
  exit 1
fi
if [[ "$1" == "api" ]]; then
  printf '%s' "${GENERATED_NOTES}"
  exit 0
fi
if [[ "$1" == "release" && "$2" == "edit" ]]; then
  prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--notes-file" ]]; then
      cp "$arg" "${NOTES_CAPTURE}"
    fi
    prev="$arg"
  done
fi
exit 0
EOF
  chmod +x "${bin}/gh"
  local log="${work}/gh.log"
  local notes="${work}/notes.md"
  set +e
  (
    cd "$work"
    PATH="${bin}:${PATH}" \
      GH_LOG="$log" \
      RELEASE_EXISTS="$exists" \
      RELEASE_BODY="$body" \
      GENERATED_NOTES=$'## Features\n- feat: add strm by @octocat in #10\n' \
      NOTES_CAPTURE="$notes" \
      GITHUB_REF_NAME="$tag" \
      GITHUB_REPOSITORY="taichijma/openlist" \
      bash "$publisher"
  ) 2>"${work}/stderr"
  local status=$?
  set -e
  printf '%s\n' "$status" >"${work}/status"
  printf '%s\n' "$log" >"${work}/logpath"
  printf '%s\n' "$notes" >"${work}/notespath"
  # shellcheck disable=SC2034
  CASE_DIR="$work"
}

# Stable release, no existing GitHub Release: create with generated notes.
run_case "create" "v1.2.3" "0" ""
status="$(cat "${CASE_DIR}/status")"
log="$(cat "${CASE_DIR}/logpath")"
if [[ "$status" != "0" ]]; then
  echo "create case exited ${status}" >&2
  failures=$((failures + 1))
fi
assert_log "$log" "release create v1.2.3 --repo taichijma/openlist --title v1.2.3 --generate-notes dist/openlist_v1.2.3_linux_amd64.tar.gz"
assert_absent "$log" "--prerelease"

# Pre-release tag.
run_case "prerelease" "v1.2.3-rc.1" "0" ""
status="$(cat "${CASE_DIR}/status")"
log="$(cat "${CASE_DIR}/logpath")"
if [[ "$status" != "0" ]]; then
  echo "prerelease case exited ${status}" >&2
  failures=$((failures + 1))
fi
assert_log "$log" "release create v1.2.3-rc.1 --repo taichijma/openlist --title v1.2.3-rc.1 --generate-notes --prerelease dist/openlist_v1.2.3-rc.1_linux_amd64.tar.gz"

# Existing release with notes: upload assets only.
run_case "keep-notes" "v1.2.4" "1" $'## Features\n- already written\n'
status="$(cat "${CASE_DIR}/status")"
log="$(cat "${CASE_DIR}/logpath")"
if [[ "$status" != "0" ]]; then
  echo "keep-notes case exited ${status}" >&2
  failures=$((failures + 1))
fi
assert_log "$log" "release upload v1.2.4 --repo taichijma/openlist --clobber dist/openlist_v1.2.4_linux_amd64.tar.gz"
assert_absent "$log" "release edit"
assert_absent "$log" "api --method POST"

# Existing release whose body is only whitespace: fill notes, then upload.
run_case "fill-notes" "v1.2.5" "1" $' \n\t'
status="$(cat "${CASE_DIR}/status")"
log="$(cat "${CASE_DIR}/logpath")"
notes="$(cat "${CASE_DIR}/notespath")"
if [[ "$status" != "0" ]]; then
  echo "fill-notes case exited ${status}" >&2
  failures=$((failures + 1))
fi
if ! grep -F -- "release edit v1.2.5 --repo taichijma/openlist --notes-file " "$log" >/dev/null; then
  echo "expected release edit with notes file" >&2
  cat "$log" >&2
  failures=$((failures + 1))
fi
if ! grep -F -- "feat: add strm" "$notes" >/dev/null; then
  echo "notes file was not passed to release edit" >&2
  failures=$((failures + 1))
fi
assert_log "$log" "release upload v1.2.5 --repo taichijma/openlist --clobber dist/openlist_v1.2.5_linux_amd64.tar.gz"

# Non-semver tags are rejected before gh is called.
run_case "invalid" "v1.2" "0" ""
status="$(cat "${CASE_DIR}/status")"
log="$(cat "${CASE_DIR}/logpath")"
if [[ "$status" == "0" ]]; then
  echo "invalid tag was accepted" >&2
  failures=$((failures + 1))
fi
if ! grep -F -- "non-semver tag" "${CASE_DIR}/stderr" >/dev/null; then
  echo "expected semver rejection" >&2
  cat "${CASE_DIR}/stderr" >&2
  failures=$((failures + 1))
fi
if [[ -s "$log" ]]; then
  echo "invalid tag invoked gh" >&2
  cat "$log" >&2
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "${failures} publish_release assertion(s) failed" >&2
  exit 1
fi
echo "publish_release_test: ok"
