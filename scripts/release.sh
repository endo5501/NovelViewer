#!/usr/bin/env bash
# Cut a release: bump pubspec.yaml, commit, tag, and push.
#
# Usage: scripts/release.sh <X.Y.Z>
#
# Runs every pre-flight check BEFORE touching anything, so a failed check
# leaves the repository exactly as it was. This is the primary guard against
# tagging a release without the matching pubspec.yaml version bump (the CI
# step scripts/verify_release_version.sh is the backstop).
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

# --- Parse arguments ----------------------------------------------------------
if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: scripts/release.sh <X.Y.Z>" >&2
  exit 1
fi
new_version="$1"

# --- Pre-flight validation (no mutations below this block) --------------------
# 1. Version must be plain SemVer major.minor.patch (no v prefix, no metadata).
if ! printf '%s' "$new_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  die "version must be in X.Y.Z format (got: '$new_version')"
fi
tag="v$new_version"

# 2. Read current version/build from pubspec.yaml.
[ -f pubspec.yaml ] || die "pubspec.yaml not found (run from the repository root)"
version_line="$(grep -E '^version:[[:space:]]*' pubspec.yaml | head -1 || true)"
[ -n "$version_line" ] || die "no 'version:' line found in pubspec.yaml"
current="${version_line#version:}"
current="${current//[[:space:]]/}"
current_name="${current%%+*}"
if [ "$current" = "$current_name" ]; then
  current_build=0           # no build metadata present
else
  current_build="${current#*+}"
fi
printf '%s' "$current_build" | grep -Eq '^[0-9]+$' || die "current build number is not an integer: '$current_build'"

# 3. Working tree must be clean.
[ -z "$(git status --porcelain)" ] || die "working tree is not clean; commit or stash changes first"

# 4. Must be on main.
branch="$(git rev-parse --abbrev-ref HEAD)"
[ "$branch" = "main" ] || die "must be on 'main' branch (current: '$branch')"

# 5. Tag must not already exist locally or on origin.
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; then
  die "tag '$tag' already exists locally"
fi
if git remote get-url origin >/dev/null 2>&1; then
  if remote_tag="$(git ls-remote --tags origin "refs/tags/$tag" 2>/dev/null)" && [ -n "$remote_tag" ]; then
    die "tag '$tag' already exists on origin"
  fi
fi

# 6. New version must be strictly greater than the current one.
ver_gt() { # ver_gt A B -> true if A > B (numeric major.minor.patch)
  local a b
  IFS=. read -r a1 a2 a3 <<<"$1"
  IFS=. read -r b1 b2 b3 <<<"$2"
  for pair in "$a1 $b1" "$a2 $b2" "$a3 $b3"; do
    a="${pair% *}"; b="${pair#* }"
    if [ "$((10#$a))" -gt "$((10#$b))" ]; then return 0; fi
    if [ "$((10#$a))" -lt "$((10#$b))" ]; then return 1; fi
  done
  return 1   # equal -> not greater
}
ver_gt "$new_version" "$current_name" || \
  die "version $new_version is not greater than current $current_name"

# --- Apply the release --------------------------------------------------------
new_build=$((current_build + 1))
new_full="$new_version+$new_build"

# Rewrite only the version line.
tmp="$(mktemp)"
sed "s|^version:.*|version: $new_full|" pubspec.yaml >"$tmp"
mv "$tmp" pubspec.yaml

echo "Bumping pubspec.yaml: $current -> $new_full"
git add pubspec.yaml
git commit -q -m "chore: bump version to $new_version"
git tag "$tag"

echo "Pushing main and $tag to origin..."
git push origin main
git push origin "$tag"

echo "Released $tag (pubspec.yaml version $new_full)."
