#!/usr/bin/env bash
# Create or update the GitHub Release for GITHUB_REF_NAME.
# Notes come from pull requests merged since the previous tag.
set -euo pipefail

tag="${GITHUB_REF_NAME:?GITHUB_REF_NAME is required}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

if [[ ! "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "refusing to release non-semver tag: $tag" >&2
  exit 1
fi

shopt -s nullglob
assets=(dist/*)
if ((${#assets[@]} == 0)); then
  echo "no release assets in dist/" >&2
  exit 1
fi

prerelease=()
if [[ "$tag" == *-* ]]; then
  prerelease=(--prerelease)
fi

notes_file=""
cleanup() {
  if [[ -n "$notes_file" && -f "$notes_file" ]]; then
    rm -f "$notes_file"
  fi
}
trap cleanup EXIT

if body="$(gh release view "$tag" --repo "$repo" --json body --jq '.body // ""' 2>/dev/null)"; then
  if [[ -z "${body//[[:space:]]/}" ]]; then
    notes_file="$(mktemp)"
    gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      "/repos/${repo}/releases/generate-notes" \
      -f tag_name="$tag" \
      --jq .body >"$notes_file"
    if [[ ! -s "$notes_file" ]]; then
      echo "GitHub returned empty release notes for ${tag}" >&2
      exit 1
    fi
    gh release edit "$tag" --repo "$repo" --notes-file "$notes_file"
  fi
  gh release upload "$tag" --repo "$repo" --clobber "${assets[@]}"
else
  gh release create "$tag" \
    --repo "$repo" \
    --title "$tag" \
    --generate-notes \
    "${prerelease[@]}" \
    "${assets[@]}"
fi
