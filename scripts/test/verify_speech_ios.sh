#!/usr/bin/env bash
# Verifies the artifacts produced by scripts/build_speech_ios.sh.
#
# Asserts the properties the iOS build must hold (spec speech-cpp-ios-build):
# the xcframework carries exactly a device and a simulator slice, each an arm64
# dynamic framework with a consistent Info.plist whose minimum OS does not
# exceed the Runner's, linking only against the OS (ggml is linked in),
# exporting the C API and nothing else, with ggml's Metal shaders embedded.
# Exits non-zero on any failure.
#
# Usage: scripts/test/verify_speech_ios.sh [xcframework-path]
set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
XCFRAMEWORK="${1:-$PROJECT_ROOT/ios/Frameworks/speech_cpp.xcframework}"
PBXPROJ="$PROJECT_ROOT/ios/Runner.xcodeproj/project.pbxproj"

# Every symbol SpeechCppNativeBindings looks up (design D5).
C_API_SYMBOLS=(
  speech_last_error
  speech_load_params_free
  speech_load_params_new
  speech_load_params_set_device
  speech_model_free
  speech_model_get_info
  speech_model_info_free
  speech_model_info_sample_rate
  speech_model_load
  speech_option_from_name
  speech_request_cancel
  speech_request_free
  speech_request_new
  speech_request_set_int
  speech_request_set_string
  speech_request_set_text
  speech_status_name
  speech_synthesize
  speech_version
  speech_voice_add
)

# slice directory name -> LC_BUILD_VERSION platform expected in its binary.
# otool prints the platform as its numeric value (PLATFORM_IOS = 2,
# PLATFORM_IOSSIMULATOR = 7) or, in some versions, by name; accept either.
SLICES=(ios-arm64 ios-arm64-simulator)
SLICE_PLATFORMS=('(2|IOS)' '(7|IOSSIMULATOR)')

# Checks run per slice once its binary exists; keep in step with check_slice.
PER_SLICE_CHECKS=13

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

# The lowest IPHONEOS_DEPLOYMENT_TARGET of the Runner's build configurations:
# the framework must load on every OS the app installs on.
runner_target="$(grep -oE 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+' "$PBXPROJ" 2>/dev/null |
  awk '{print $3}' | sort -V | head -n 1)"

# version_le <a> <b> : true when version a is at most version b.
version_le() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]
}

check_slice() {
  local slice="$1" platform="$2"
  local framework="$XCFRAMEWORK/$slice/speech_cpp.framework"
  local binary="$framework/speech_cpp"
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

  check_eq "$slice: CFBundleExecutable is speech_cpp" "speech_cpp" "$(plist_value "$plist" CFBundleExecutable)"
  check_eq "$slice: CFBundlePackageType is FMWK" "FMWK" "$(plist_value "$plist" CFBundlePackageType)"
  check_eq "$slice: MinimumOSVersion matches the binary minos" "${minos:-<none>}" "$(plist_value "$plist" MinimumOSVersion)"

  if [ -n "$minos" ] && [ -n "$runner_target" ] && version_le "$minos" "$runner_target"; then
    ok "$slice: minos $minos does not exceed the Runner's $runner_target"
  else
    ng "$slice: minos does not exceed the Runner's deployment target (minos '${minos:-<none>}', Runner '${runner_target:-<none>}')"
  fi

  check_eq "$slice: install name is @rpath/speech_cpp.framework/speech_cpp" \
    "@rpath/speech_cpp.framework/speech_cpp" "$(otool -D "$binary" 2>/dev/null | tail -n 1)"

  # The first entry of otool -L for a dylib is its own install name.
  local foreign
  foreign="$(otool -L "$binary" 2>/dev/null | tail -n +2 | awk '{print $1}' |
    grep -vE '^(/System/Library/|/usr/lib/|@rpath/speech_cpp\.framework/speech_cpp$)' | grep -v '^$' || true)"
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

  # Statically linked ggml must stay hidden. The linker's own Mach-O header
  # symbol is the one tolerated exception.
  extra="$(printf '%s\n' "$exported" | grep -vE '^(_speech_|__mh_dylib_header$)' | grep -v '^$' | head -20 || true)"
  check_empty "$slice: exports nothing but the C API" "$extra"

  # GGML_METAL_EMBED_LIBRARY compiles the shader source in as text; without it
  # ggml looks for a default.metallib the app does not ship. Kernel names are
  # not searchable as strings, so look for the definitions themselves.
  if strings -n 6 "$binary" 2>/dev/null | grep -q '^kernel void '; then
    ok "$slice: Metal shader source is embedded"
  else
    ng "$slice: Metal shader source is embedded"
  fi
}

printf 'Verifying: %s\n\n' "$XCFRAMEWORK"

if [ ! -d "$XCFRAMEWORK" ]; then
  ng "speech_cpp.xcframework exists"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  printf 'Hint: run scripts/build_speech_ios.sh first.\n'
  exit 1
fi
ok "speech_cpp.xcframework exists"

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
      [ "$(entry LibraryPath)" = speech_cpp.framework ] &&
      [ "$(entry BinaryPath)" = speech_cpp.framework/speech_cpp ]; then
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

for i in "${!SLICES[@]}"; do
  printf '\n'
  check_slice "${SLICES[$i]}" "${SLICE_PLATFORMS[$i]}"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"

# A check that dies before reaching ok/ng leaves the summary reading "0 failed"
# while having verified nothing, so assert the count as well as the verdicts.
EXPECTED_CHECKS=$((3 + ${#SLICES[@]} * PER_SLICE_CHECKS))
if [ $((pass + fail)) -ne "$EXPECTED_CHECKS" ]; then
  printf 'FAIL - expected %d checks to run, but %d did\n' \
    "$EXPECTED_CHECKS" "$((pass + fail))"
  exit 1
fi

[ "$fail" -eq 0 ]
