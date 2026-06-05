#!/usr/bin/env bash
# Tests for scripts/verify_release_version.sh
#
# Runs the verify script against throwaway pubspec.yaml files and asserts the
# exit code. Pure unit tests: no git, no network.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY="$SCRIPT_DIR/verify_release_version.sh"

pass=0
fail=0

# run_case <description> <expected-exit> <tag> <pubspec-version-line-value>
run_case() {
  local desc="$1" expected="$2" tag="$3" version="$4"
  local tmp
  tmp="$(mktemp -d)"
  printf 'name: novel_viewer\nversion: %s\n' "$version" >"$tmp/pubspec.yaml"
  ( cd "$tmp" && bash "$VERIFY" "$tag" ) >/dev/null 2>&1
  local actual=$?
  rm -rf "$tmp"
  if [ "$actual" -eq "$expected" ]; then
    pass=$((pass + 1))
    printf 'ok   - %s\n' "$desc"
  else
    fail=$((fail + 1))
    printf 'FAIL - %s (expected exit %s, got %s)\n' "$desc" "$expected" "$actual"
  fi
}

# Matching tag and version (build metadata ignored) -> success
run_case "tag matches version, build metadata ignored" 0 "v1.2.0" "1.2.0+4"
run_case "tag matches version without build metadata"   0 "v1.2.0" "1.2.0"
run_case "tag without leading v still matches"          0 "1.2.0"  "1.2.0+4"

# Mismatched tag and version -> failure (the bug we are guarding against)
run_case "tag newer than pubspec -> mismatch" 1 "v1.2.0" "1.1.0+3"
run_case "tag older than pubspec -> mismatch" 1 "v1.0.0" "1.1.0+3"
run_case "patch mismatch -> mismatch"         1 "v1.2.1" "1.2.0+4"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
