#!/usr/bin/env bash
# Create a versioned GitHub Release from the command line.
#
# Usage:
#   ./scripts/release.sh 1.1.0+2
#
# What it does:
#   1. Writes version into pubspec.yaml
#   2. Commits the bump
#   3. Tags v1.1.0 (version name, without +build)
#   4. Pushes master + tag
#
# GitHub Actions then builds the APK and:
#   - replaces the rolling apk-latest release
#   - creates a kept versioned release for the tag
#
# Other commands:
#   git push origin master              # build APK + replace apk-latest only
#   git commit -m "fix: foo [skip apk]" # push without building APK
#   git commit -m "feat: foo [release]" # push and also create a versioned release
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ "${1:-}" = "" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 1.1.0+2"
  echo
  echo "Current pubspec version: $(grep '^version:' pubspec.yaml | awk '{print $2}')"
  exit 1
fi

VERSION="$1"
if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
  echo "Invalid version '$VERSION'. Use Flutter format: 1.1.0 or 1.1.0+2"
  exit 1
fi

TAG="v${VERSION%%+*}"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists. Choose a new version."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean. Commit or stash your changes first."
  exit 1
fi

sed -i.bak -E "s/^version: .*/version: ${VERSION}/" pubspec.yaml
rm -f pubspec.yaml.bak

git add pubspec.yaml
git commit -m "chore: bump version to ${VERSION} [release]"

git tag -a "$TAG" -m "Release ${VERSION}"
git push origin HEAD
git push origin "$TAG"

echo
echo "Pushed ${TAG}. GitHub Actions will build the APK and create the versioned release."
echo "Track it at: https://github.com/if12is/islamic-app/actions"
