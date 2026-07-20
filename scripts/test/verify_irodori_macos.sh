#!/usr/bin/env bash
# Verifies the artifacts produced by scripts/build_irodori_macos.sh.
#
# Asserts the properties the macOS build must hold: the dylib exists, links
# only against system frameworks (no Homebrew paths — libomp must be linked
# statically), carries the Metal backend, exports the C API, and has the model
# spec compiled in rather than shipped beside it. Exits non-zero on any failure.
#
# Usage: scripts/test/verify_irodori_macos.sh [frameworks-dir]
set -u

FRAMEWORKS_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/macos/Frameworks}"
DYLIB="$FRAMEWORKS_DIR/libaudiocpp_ffi.dylib"

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

# check_cmd <description> <command...> : passes when the command succeeds.
# Named apart from release_test.sh's check(), which takes an exit code instead.
#
# Callers must not attach redirections here: a redirection that fails aborts the
# invocation before either counter moves, so the check disappears from the run
# while the summary still reports zero failures. Pass text through check_match
# instead, which pipes (no temp file) from inside the function.
check_cmd() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else ng "$desc"; fi
}

# check_match <description> <extended-regex> <text>
check_match() {
  local desc="$1" pattern="$2" text="$3"
  if printf '%s\n' "$text" | grep -qE "$pattern"; then ok "$desc"; else ng "$desc"; fi
}

printf 'Verifying: %s\n\n' "$DYLIB"

if [ ! -f "$DYLIB" ]; then
  ng "libaudiocpp_ffi.dylib exists"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  printf 'Hint: run scripts/build_irodori_macos.sh first.\n'
  exit 1
fi
ok "libaudiocpp_ffi.dylib exists"

otool_out="$(otool -L "$DYLIB" 2>/dev/null)"

# libomp must be statically linked: nothing under Homebrew's prefix may remain.
brew_deps="$(printf '%s\n' "$otool_out" | grep -E '/opt/homebrew|/usr/local/opt' || true)"
if [ -n "$brew_deps" ]; then
  ng "no Homebrew library dependencies (libomp is linked statically)"
  printf '%s\n' "$brew_deps" | sed 's/^/       /'
else
  ok "no Homebrew library dependencies (libomp is linked statically)"
fi

check_match "Metal.framework is linked" 'Metal\.framework' "$otool_out"
check_match "MetalKit.framework is linked" 'MetalKit\.framework' "$otool_out"
check_match "install name is @rpath/libaudiocpp_ffi.dylib" \
  '@rpath/libaudiocpp_ffi\.dylib' "$otool_out"

# Undefined OpenMP symbols would mean the runtime was not linked in at all.
# Match the symbol name only (field 2 of nm -u output is absent, so the whole
# line is the symbol) to avoid false hits such as _OBJC_CLASS_$_MTLCompileOptions.
undef_omp="$(nm -u "$DYLIB" 2>/dev/null | grep -cE '^_(__kmpc|omp_|__kmp)' || true)"
if [ "$undef_omp" -eq 0 ]; then
  ok "no undefined OpenMP symbols"
else
  ng "no undefined OpenMP symbols (found $undef_omp)"
fi

# ...and the runtime must actually be present, i.e. OpenMP was not silently
# disabled. Static linking pulls the kmpc entry points into the image.
embedded_omp="$(nm -a "$DYLIB" 2>/dev/null | grep -cE '__kmpc|_omp_' || true)"
if [ "$embedded_omp" -gt 0 ]; then
  ok "OpenMP runtime is embedded ($embedded_omp symbols)"
else
  ng "OpenMP runtime is embedded (found none — was OpenMP disabled?)"
fi

check_match "audiocpp C API is exported" '_audiocpp_init' \
  "$(nm -gU "$DYLIB" 2>/dev/null)"

# The spec is compiled in via AUDIOCPP_DEPLOYMENT_BUILD. Shipping it as a file
# under Frameworks instead would fail codesign, which seals that directory.
check_cmd "model spec is compiled into the dylib" \
  grep -aq '"family": *"irodori_tts"' "$DYLIB"

check_cmd "no model_specs directory beside the dylib (would break codesign)" \
  test ! -e "$FRAMEWORKS_DIR/model_specs"

# The Metal shader library is embedded into the dylib by ggml, so no separate
# metallib should be shipped.
check_cmd "no standalone default.metallib (Metal library is embedded)" \
  test ! -e "$FRAMEWORKS_DIR/default.metallib"

printf '\n%d passed, %d failed\n' "$pass" "$fail"

# A check that dies before reaching ok/ng leaves the summary reading "0 failed"
# while having verified nothing, so assert the count as well as the verdicts.
EXPECTED_CHECKS=11
if [ $((pass + fail)) -ne "$EXPECTED_CHECKS" ]; then
  printf 'FAIL - expected %d checks to run, but %d did\n' \
    "$EXPECTED_CHECKS" "$((pass + fail))"
  exit 1
fi

[ "$fail" -eq 0 ]
