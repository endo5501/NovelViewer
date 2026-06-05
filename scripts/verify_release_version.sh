#!/usr/bin/env bash
# Verify that a release tag matches pubspec.yaml's version.
#
# Usage: verify_release_version.sh <tag>
#
# Compares the tag (leading `v` stripped) against pubspec.yaml's `version`
# (build metadata `+N` stripped). Exits 0 on match, 1 on mismatch.
#
# Used as a CI guard in .github/workflows/release.yml so a tag pushed without
# the matching pubspec.yaml bump fails before any build or release is published.
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: verify_release_version.sh <tag>" >&2
  exit 1
fi

tag="$1"
# Strip a single leading "v" (e.g. v1.2.0 -> 1.2.0).
tag_version="${tag#v}"

pubspec="${PUBSPEC_PATH:-pubspec.yaml}"
if [ ! -f "$pubspec" ]; then
  echo "error: $pubspec not found (run from the repository root)" >&2
  exit 1
fi

# Extract the value of the `version:` line, then drop build metadata (+N).
version_line="$(grep -E '^version:[[:space:]]*' "$pubspec" | head -1 || true)"
if [ -z "$version_line" ]; then
  echo "error: no 'version:' line found in $pubspec" >&2
  exit 1
fi
pubspec_version="${version_line#version:}"
pubspec_version="${pubspec_version//[[:space:]]/}"
pubspec_version="${pubspec_version%%+*}"

if [ "$tag_version" != "$pubspec_version" ]; then
  echo "error: tag/pubspec version mismatch" >&2
  echo "  tag          : $tag (-> $tag_version)" >&2
  echo "  pubspec.yaml : $pubspec_version" >&2
  echo "Bump pubspec.yaml to $tag_version before tagging (see scripts/release.sh)." >&2
  exit 1
fi

echo "ok: tag $tag matches pubspec.yaml version $pubspec_version"
