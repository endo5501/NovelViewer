#!/usr/bin/env bash
# Verifies the artifacts produced by scripts/build_irodori_macos.sh.
#
# Asserts the properties the macOS build must hold: the dylib exists, links
# only against system frameworks (no Homebrew paths — libomp must be linked
# statically), carries the Metal backend, exports the C API, and ships the
# model spec next to itself. Exits non-zero if any check fails.
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

# check <description> <command...> : passes when the command succeeds
check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else ng "$desc"; fi
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
if printf '%s' "$otool_out" | grep -q '/opt/homebrew\|/usr/local/opt'; then
  ng "no Homebrew library dependencies (libomp is linked statically)"
  printf '%s\n' "$otool_out" | grep '/opt/homebrew\|/usr/local/opt' | sed 's/^/       /'
else
  ok "no Homebrew library dependencies (libomp is linked statically)"
fi

check "Metal.framework is linked" \
  grep -q 'Metal.framework' <<<"$otool_out"
check "MetalKit.framework is linked" \
  grep -q 'MetalKit.framework' <<<"$otool_out"
check "install name is @rpath/libaudiocpp_ffi.dylib" \
  grep -q '@rpath/libaudiocpp_ffi.dylib' <<<"$otool_out"

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

check "audiocpp C API is exported" \
  grep -q '_audiocpp_init' <<<"$(nm -gU "$DYLIB" 2>/dev/null)"

# The spec is compiled in via AUDIOCPP_DEPLOYMENT_BUILD. Shipping it as a file
# under Frameworks instead would fail codesign, which seals that directory.
check "model spec is compiled into the dylib" \
  grep -q '"family": *"irodori_tts"' <<<"$(strings "$DYLIB" 2>/dev/null)"

if [ -e "$FRAMEWORKS_DIR/model_specs" ]; then
  ng "no model_specs directory beside the dylib (would break codesign)"
else
  ok "no model_specs directory beside the dylib (would break codesign)"
fi

# The Metal shader library is embedded into the dylib by ggml, so no separate
# metallib should be shipped.
if [ -e "$FRAMEWORKS_DIR/default.metallib" ]; then
  ng "no standalone default.metallib (Metal library is embedded)"
else
  ok "no standalone default.metallib (Metal library is embedded)"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
