#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository. version.txt not updated."
    exit 1
fi

VERSION="$(git describe --tags --dirty --always 2>/dev/null || true)"
if [ -z "$VERSION" ]; then
    VERSION="commit-$(git rev-parse --short HEAD)"
fi

if [ -f "version.txt" ]; then
    tail -n +2 version.txt > /tmp/version_body.$$ 2>/dev/null || true
    printf "%s\n" "$VERSION" > version.txt
    cat /tmp/version_body.$$ >> version.txt
    rm -f /tmp/version_body.$$
else
    printf "%s\n" "$VERSION" > version.txt
fi

echo "Updated version.txt to $VERSION"
