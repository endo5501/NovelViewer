#!/usr/bin/env bash
# Integration tests for scripts/release.sh
#
# Each test builds a throwaway git repo (with a bare "origin" remote so pushes
# stay local) and runs release.sh against it. Validation-failure cases assert
# that the repo is left completely untouched; the happy path asserts the version
# bump, commit, tag, and push all happened.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="$SCRIPT_DIR/release.sh"

pass=0
fail=0
check() { # check <description> <condition-exit-code>
  if [ "$2" -eq 0 ]; then pass=$((pass + 1)); printf 'ok   - %s\n' "$1"
  else fail=$((fail + 1)); printf 'FAIL - %s\n' "$1"; fi
}

# make_repo <dir> <pubspec-version> : init a repo on main with one commit and a
# bare remote wired up as origin.
make_repo() {
  local dir="$1" version="$2"
  git init -q "$dir"
  git -C "$dir" config user.email t@t; git -C "$dir" config user.name t
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" checkout -q -b main 2>/dev/null || git -C "$dir" branch -q -M main
  printf 'name: novel_viewer\nversion: %s\n' "$version" >"$dir/pubspec.yaml"
  git -C "$dir" add pubspec.yaml; git -C "$dir" commit -q -m init
  git init -q --bare "$dir.remote"
  git -C "$dir" remote add origin "$dir.remote"
  git -C "$dir" push -q origin main
}

pubspec_version() { grep -E '^version:' "$1/pubspec.yaml" | sed 's/version:[[:space:]]*//'; }
commit_count() { git -C "$1" rev-list --count HEAD; }
tag_exists() { git -C "$1" rev-parse -q --verify "refs/tags/$2" >/dev/null 2>&1; }

# run_release <dir> <args...> : returns the script exit code.
run_release() { local d="$1"; shift; ( cd "$d" && bash "$RELEASE" "$@" ); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- Validation failures: must exit non-zero AND leave the repo untouched -----
assert_untouched_failure() { # <name> <repo> <expected-pubspec> <args...>
  local name="$1" repo="$2" want="$3"; shift 3
  local before_commits; before_commits="$(commit_count "$repo")"
  run_release "$repo" "$@" >/dev/null 2>&1; local rc=$?
  [ "$rc" -ne 0 ]; check "$name: exits non-zero" $?
  [ "$(pubspec_version "$repo")" = "$want" ]; check "$name: pubspec unchanged" $?
  [ "$(commit_count "$repo")" = "$before_commits" ]; check "$name: no new commit" $?
}

r="$work/fmt"; make_repo "$r" "1.1.0+3"
assert_untouched_failure "invalid format (1.2)" "$r" "1.1.0+3" "1.2"
assert_untouched_failure "invalid format (v-prefix)" "$r" "1.1.0+3" "v1.2.0"
assert_untouched_failure "invalid format (suffix)" "$r" "1.1.0+3" "1.2.0-beta"
assert_untouched_failure "no argument" "$r" "1.1.0+3"

# Dirty the tracked pubspec by changing a different line; the version: line
# itself stays 1.1.0+3, so that is what "pubspec unchanged" should observe.
r="$work/dirty"; make_repo "$r" "1.1.0+3"
sed -i 's/^name: .*/name: dirtied/' "$r/pubspec.yaml"
assert_untouched_failure "dirty working tree" "$r" "1.1.0+3" "1.2.0"

r="$work/branch"; make_repo "$r" "1.1.0+3"; git -C "$r" checkout -q -b feature
assert_untouched_failure "not on main" "$r" "1.1.0+3" "1.2.0"

r="$work/tagdup"; make_repo "$r" "1.1.0+3"; git -C "$r" tag v1.2.0
assert_untouched_failure "tag already exists" "$r" "1.1.0+3" "1.2.0"

r="$work/regress"; make_repo "$r" "1.2.0+3"
assert_untouched_failure "version regression" "$r" "1.2.0+3" "1.1.0"
assert_untouched_failure "version equal (not greater)" "$r" "1.2.0+3" "1.2.0"

# --- Happy path: bump build, commit, tag, push --------------------------------
r="$work/ok"; make_repo "$r" "1.1.0+3"
run_release "$r" "1.2.0" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ]; check "happy: exits zero" $?
[ "$(pubspec_version "$r")" = "1.2.0+4" ]; check "happy: build number incremented to 1.2.0+4" $?
tag_exists "$r" v1.2.0; check "happy: tag v1.2.0 created" $?
git -C "$r" log -1 --pretty=%s | grep -q "1.2.0"; check "happy: commit message mentions version" $?
git -C "$r.remote" rev-parse -q --verify refs/tags/v1.2.0 >/dev/null 2>&1; check "happy: tag pushed to origin" $?
[ -z "$(git -C "$r" status --porcelain)" ]; check "happy: working tree clean after release" $?

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
