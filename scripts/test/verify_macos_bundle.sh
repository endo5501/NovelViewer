#!/usr/bin/env bash
# Verifies which native libraries end up inside the built macOS .app.
#
# The Embed Native Libraries build phase globs macos/Frameworks/*.dylib rather
# than listing names, so whatever sits in that directory gets embedded and
# signed. That removes the old three-list drift problem but introduces a new
# one: a stray file dropped into macos/Frameworks/ silently ships. This script
# is the guard — it asserts the embedded set is exactly the expected one, on
# both sides of the copy.
#
# Usage: scripts/test/verify_macos_bundle.sh [app-bundle]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="${1:-$REPO_ROOT/build/macos/Build/Products/Release/novel_viewer.app}"
FRAMEWORKS_DIR="$REPO_ROOT/macos/Frameworks"
BUNDLE_FRAMEWORKS="$APP/Contents/Frameworks"

# The libraries this project embeds, one per native engine plus ONNX Runtime.
# Adding an engine means adding its dylib here as well — that is deliberate:
# this list is the assertion, not the source of truth the build reads from.
EXPECTED_DYLIBS="libaudiocpp_ffi.dylib
liblame_enc_ffi.dylib
libonnxruntime.dylib
libpiper_tts_ffi.dylib
libqwen3_tts_ffi.dylib"

pass=0
fail=0

ok() {
  pass=$((pass + 1))
  printf 'ok   - %s\n' "$1"
}

ng() {
  fail=$((fail + 1))
  printf 'FAIL - %s\n' "$1"
}

# list_dylibs <dir> : basenames of *.dylib in <dir>, sorted, one per line.
# Prints nothing when the directory holds none (the glob is guarded, so the
# literal pattern never leaks into the output).
list_dylibs() {
  local dir="$1" f
  for f in "$dir"/*.dylib; do
    [ -f "$f" ] || continue
    basename "$f"
  done | sort
}

# diff_set <description> <expected> <actual>
diff_set() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ok "$desc"
    return
  fi
  ng "$desc"
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") |
    sed 's/^/       /'
}

printf 'Verifying: %s\n\n' "$APP"

if [ ! -d "$APP" ]; then
  ng "app bundle exists"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  printf 'Hint: run `fvm flutter build macos` first.\n'
  exit 1
fi
ok "app bundle exists"

# Source side: catches a stray dylib before it ever reaches the bundle.
diff_set "macos/Frameworks holds exactly the expected dylibs" \
  "$EXPECTED_DYLIBS" "$(list_dylibs "$FRAMEWORKS_DIR")"

# Bundle side: catches the phase copying too much, too little, or nothing.
embedded="$(list_dylibs "$BUNDLE_FRAMEWORKS")"
diff_set "the bundle embeds exactly the expected dylibs" \
  "$EXPECTED_DYLIBS" "$embedded"

# Every embedded dylib must be signed, or the enclosing bundle's signature is
# invalid ("code object is not signed at all").
unsigned=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  codesign -dv "$BUNDLE_FRAMEWORKS/$name" >/dev/null 2>&1 ||
    unsigned="$unsigned $name"
done <<<"$embedded"
if [ -z "$unsigned" ]; then
  ok "every embedded dylib is code signed"
else
  ng "every embedded dylib is code signed (unsigned:$unsigned)"
fi

if codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
  ok "codesign --verify --deep --strict passes"
else
  ng "codesign --verify --deep --strict passes"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"

# A check that dies before reaching ok/ng leaves the summary reading "0 failed"
# while having verified nothing, so assert the count as well as the verdicts.
EXPECTED_CHECKS=5
if [ $((pass + fail)) -ne "$EXPECTED_CHECKS" ]; then
  printf 'FAIL - expected %d checks to run, but %d did\n' \
    "$EXPECTED_CHECKS" "$((pass + fail))"
  exit 1
fi

[ "$fail" -eq 0 ]
