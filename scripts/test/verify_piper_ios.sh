#!/usr/bin/env bash
# Verifies the artifacts produced by scripts/build_piper_ios.sh.
#
# Asserts the properties the iOS build must hold (spec piper-ios-build): the
# xcframework carries exactly a device and a simulator slice, each an arm64
# dynamic framework with a consistent Info.plist, linking only against the OS
# (ONNX Runtime is linked in), exporting the C API and nothing else, and never
# referencing a process-spawning function (the App Sandbox forbids them, and
# the patch exists to keep OpenJTalk off that path). Exits non-zero on any
# failure.
#
# Usage: scripts/test/verify_piper_ios.sh [xcframework-path]
set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
XCFRAMEWORK="${1:-$PROJECT_ROOT/ios/Frameworks/piper_plus.xcframework}"

# Every symbol PiperNativeBindings looks up.
C_API_SYMBOLS=(
  piper_plus_api_version
  piper_plus_create
  piper_plus_default_options
  piper_plus_free
  piper_plus_free_audio
  piper_plus_get_last_error
  piper_plus_language_id
  piper_plus_phonemize
  piper_plus_sample_rate
  piper_plus_synthesize
)

# Functions that start another process. None may be referenced: iOS does not
# allow them, and a reference means a desktop-only path was linked in.
SPAWN_SYMBOLS_REGEX='^_(popen|system|fork|vfork|posix_spawn|posix_spawnp|execl|execle|execlp|execv|execve|execvp)$'

# slice directory name -> LC_BUILD_VERSION platform expected in its binary.
# otool prints the platform as its numeric value (PLATFORM_IOS = 2,
# PLATFORM_IOSSIMULATOR = 7) or, in some versions, by name; accept either.
SLICES=(ios-arm64 ios-arm64-simulator)
SLICE_PLATFORMS=('(2|IOS)' '(7|IOSSIMULATOR)')

# Checks run per slice once its binary exists; keep in step with check_slice.
PER_SLICE_CHECKS=12

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

# check_eq <description> <expected> <actual>
check_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else ng "$1 (expected '$2', got '$3')"; fi
}

# check_match <description> <extended-regex> <text>
check_match() {
  local desc="$1" pattern="$2" text="$3"
  if printf '%s\n' "$text" | grep -qE "$pattern"; then ok "$desc"; else ng "$desc"; fi
}

# check_empty <description> <text> : passes when text is empty, else lists it.
check_empty() {
  if [ -z "$2" ]; then
    ok "$1"
  else
    ng "$1"
    printf '%s\n' "$2" | sed 's/^/       /'
  fi
}

plist_value() {
  plutil -extract "$2" raw -o - "$1" 2>/dev/null || true
}

check_slice() {
  local slice="$1" platform="$2"
  local framework="$XCFRAMEWORK/$slice/piper_plus.framework"
  local binary="$framework/piper_plus"
  local plist="$framework/Info.plist"

  if [ ! -f "$binary" ]; then
    ng "$slice: framework binary exists"
    # The remaining checks cannot run; count them as failures so the summary
    # does not read as a smaller, passing run.
    fail=$((fail + PER_SLICE_CHECKS - 1))
    printf 'FAIL - %s: %d further checks skipped\n' "$slice" "$((PER_SLICE_CHECKS - 1))"
    return
  fi
  ok "$slice: framework binary exists"

  check_eq "$slice: architecture is arm64 only" "arm64" "$(lipo -archs "$binary" 2>/dev/null)"
  check_match "$slice: binary is a dynamic library" 'DYLIB' "$(otool -hv "$binary" 2>/dev/null)"

  local load_commands minos
  load_commands="$(otool -l "$binary" 2>/dev/null)"
  check_match "$slice: built for platform $platform" "platform $platform\$" \
    "$(printf '%s\n' "$load_commands" | awk '/LC_BUILD_VERSION/{f=1} f&&/platform/{print; exit}' | sed 's/^ *//')"
  minos="$(printf '%s\n' "$load_commands" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')"

  check_eq "$slice: CFBundleExecutable is piper_plus" "piper_plus" "$(plist_value "$plist" CFBundleExecutable)"
  check_eq "$slice: CFBundlePackageType is FMWK" "FMWK" "$(plist_value "$plist" CFBundlePackageType)"
  check_eq "$slice: MinimumOSVersion matches the binary minos" "${minos:-<none>}" "$(plist_value "$plist" MinimumOSVersion)"

  check_eq "$slice: install name is @rpath/piper_plus.framework/piper_plus" \
    "@rpath/piper_plus.framework/piper_plus" "$(otool -D "$binary" 2>/dev/null | tail -n 1)"

  # The first entry of otool -L for a dylib is its own install name.
  local foreign
  foreign="$(otool -L "$binary" 2>/dev/null | tail -n +2 | awk '{print $1}' |
    grep -vE '^(/System/Library/|/usr/lib/|@rpath/piper_plus\.framework/piper_plus$)' | grep -v '^$' || true)"
  check_empty "$slice: depends only on the OS" "$foreign"

  local exported missing="" extra
  exported="$(nm -gU "$binary" 2>/dev/null | awk '{print $3}')"
  for sym in "${C_API_SYMBOLS[@]}"; do
    printf '%s\n' "$exported" | grep -qx "_$sym" || missing="$missing $sym"
  done
  if [ -z "$missing" ]; then
    ok "$slice: all ${#C_API_SYMBOLS[@]} C API functions are exported"
  else
    ng "$slice: all ${#C_API_SYMBOLS[@]} C API functions are exported (missing:$missing)"
  fi

  # Statically linked ONNX Runtime / fmt / spdlog / OpenJTalk must stay hidden.
  # The linker's own Mach-O header symbol is the one tolerated exception.
  extra="$(printf '%s\n' "$exported" | grep -vE '^(_piper_plus_|__mh_dylib_header$)' | grep -v '^$' | head -20 || true)"
  check_empty "$slice: exports nothing but the C API" "$extra"

  local spawn
  spawn="$(nm -u "$binary" 2>/dev/null | grep -E "$SPAWN_SYMBOLS_REGEX" || true)"
  check_empty "$slice: references no process-spawning function" "$spawn"
}

printf 'Verifying: %s\n\n' "$XCFRAMEWORK"

if [ ! -d "$XCFRAMEWORK" ]; then
  ng "piper_plus.xcframework exists"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  printf 'Hint: run scripts/build_piper_ios.sh first.\n'
  exit 1
fi
ok "piper_plus.xcframework exists"

actual_slices="$(find "$XCFRAMEWORK" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ' | sed 's/ $//')"
check_eq "xcframework holds exactly the device and simulator slices" \
  "$(printf '%s\n' "${SLICES[@]}" | sort | tr '\n' ' ' | sed 's/ $//')" "$actual_slices"

# The Runner's embed phase selects slices from the root manifest, not from the
# directory layout, so the manifest must describe exactly these two slices with
# the platform variant each is built for.
manifest="$XCFRAMEWORK/Info.plist"
manifest_problems=""
# entry <key> : that key of manifest entry $j, or empty when absent.
entry() { /usr/libexec/PlistBuddy -c "Print :AvailableLibraries:$j:$1" "$manifest" 2>/dev/null || true; }
entries=0
while /usr/libexec/PlistBuddy -c "Print :AvailableLibraries:$entries" "$manifest" >/dev/null 2>&1; do
  entries=$((entries + 1))
done
[ "$entries" -eq "${#SLICES[@]}" ] || manifest_problems="$manifest_problems ${entries}-entries"
for i in "${!SLICES[@]}"; do
  slice="${SLICES[$i]}"
  [ "$slice" = ios-arm64-simulator ] && want_variant=simulator || want_variant=""
  found=0
  j=0
  while [ "$j" -lt "$entries" ]; do
    if [ "$(entry LibraryIdentifier)" = "$slice" ] &&
      [ "$(entry SupportedPlatform)" = ios ] &&
      [ "$(entry SupportedPlatformVariant)" = "$want_variant" ] &&
      [ "$(entry LibraryPath)" = piper_plus.framework ] &&
      [ "$(entry BinaryPath)" = piper_plus.framework/piper_plus ]; then
      found=1
    fi
    j=$((j + 1))
  done
  [ "$found" -eq 1 ] || manifest_problems="$manifest_problems $slice"
done
if [ -z "$manifest_problems" ]; then
  ok "root Info.plist describes the device and simulator slices"
else
  ng "root Info.plist describes the device and simulator slices (wrong:$manifest_problems)"
fi

# ONNX Runtime is linked into piper_plus (design D4); a separate copy would be
# embedded by the Runner's phase and duplicate it.
standalone_ort="$(find "$(dirname "$XCFRAMEWORK")" -maxdepth 1 -iname 'onnxruntime*.xcframework' | wc -l | tr -d ' ')"
check_eq "no standalone ONNX Runtime xcframework" "0" "$standalone_ort"

for i in "${!SLICES[@]}"; do
  printf '\n'
  check_slice "${SLICES[$i]}" "${SLICE_PLATFORMS[$i]}"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"

# A check that dies before reaching ok/ng leaves the summary reading "0 failed"
# while having verified nothing, so assert the count as well as the verdicts.
EXPECTED_CHECKS=$((4 + ${#SLICES[@]} * PER_SLICE_CHECKS))
if [ $((pass + fail)) -ne "$EXPECTED_CHECKS" ]; then
  printf 'FAIL - expected %d checks to run, but %d did\n' \
    "$EXPECTED_CHECKS" "$((pass + fail))"
  exit 1
fi

[ "$fail" -eq 0 ]
