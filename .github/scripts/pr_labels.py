#!/usr/bin/env python3
"""Label a pull request so GitHub release notes can group it.

The mapping follows Conventional Commits titles. Release sections live in
.github/release.yml.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

CONVENTIONAL = re.compile(
    r"^(?P<type>feat|feature|fix|docs)(?:\([^)]+\))?!?:",
    re.IGNORECASE,
)
TITLE_BREAKING = re.compile(r"^[a-z]+(\([^)]+\))?!:", re.IGNORECASE)
BREAKING_FOOTER = re.compile(r"(?m)^BREAKING CHANGE:")

# name -> (color, description). Created if the repository does not have them yet.
CATALOG = {
    "breaking-change": ("b60205", "Listed under Breaking changes in release notes"),
    "enhancement": ("a2eeef", "Listed under Features in release notes"),
    "bug": ("d73a4a", "Listed under Bug fixes in release notes"),
    "documentation": ("0075ca", "Listed under Documentation in release notes"),
    "ignore-for-release": ("ededed", "Omit this pull request from generated release notes"),
}


def labels_for(title: str, body: str) -> list[str]:
    """Return release-note labels for a pull request title and body."""
    labels: list[str] = []
    title = title.strip()
    match = CONVENTIONAL.match(title)
    breaking = bool(TITLE_BREAKING.match(title)) or bool(BREAKING_FOOTER.search(body or ""))
    if breaking:
        labels.append("breaking-change")
    if not match:
        return labels
    kind = match.group("type").lower()
    if kind in {"feat", "feature"}:
        labels.append("enhancement")
    elif kind == "fix":
        labels.append("bug")
    elif kind == "docs":
        labels.append("documentation")
    return labels


def ensure_labels(repo: str) -> None:
    listed = subprocess.run(
        ["gh", "label", "list", "--repo", repo, "--limit", "200", "--json", "name"],
        check=True,
        capture_output=True,
        text=True,
    )
    existing = {item["name"] for item in json.loads(listed.stdout or "[]")}
    for name, (color, description) in CATALOG.items():
        if name in existing:
            continue
        subprocess.run(
            [
                "gh",
                "label",
                "create",
                name,
                "--repo",
                repo,
                "--color",
                color,
                "--description",
                description,
            ],
            check=True,
        )


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    repo = os.environ.get("GITHUB_REPOSITORY")
    if not event_path or not repo:
        print("GITHUB_EVENT_PATH and GITHUB_REPOSITORY are required", file=sys.stderr)
        return 1
    with open(event_path, encoding="utf-8") as handle:
        event = json.load(handle)
    pull_request = event.get("pull_request") or {}
    number = pull_request.get("number")
    if not number:
        print("event has no pull_request.number", file=sys.stderr)
        return 1

    ensure_labels(repo)
    labels = labels_for(pull_request.get("title") or "", pull_request.get("body") or "")
    if not labels:
        return 0

    command = ["gh", "pr", "edit", str(number), "--repo", repo]
    for label in labels:
        command.extend(["--add-label", label])
    subprocess.run(command, check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
