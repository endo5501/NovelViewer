#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PIPER_DIR="$PROJECT_ROOT/third_party/piper-plus"
FRAMEWORKS_DIR="$PROJECT_ROOT/macos/Frameworks"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

# The prebuilt ONNX Runtime 1.20.0 that piper-plus downloads targets macOS 13.3,
# so that is the real floor for Piper. Without an explicit target, CMake uses the
# build host's OS version, which would make libpiper_plus demand whatever macOS
# the developer happened to build on. Exported (not just passed as
# -DCMAKE_OSX_DEPLOYMENT_TARGET) because piper-plus builds OpenJTalk, fmt and
# spdlog as ExternalProjects, which do not inherit the parent's cache variables
# but do read this environment variable.
DEPLOYMENT_TARGET="13.3"
export MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"

echo "=== Building piper_plus shared library (upstream C API, CPU only) ==="
mkdir -p "$PIPER_DIR/build"
cmake -S "$PIPER_DIR" -B "$PIPER_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPIPER_PLUS_BUILD_SHARED=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
cmake --build "$PIPER_DIR/build" --config Release --target piper_plus -j "$NUM_CORES"

echo "=== Copying shared libraries to macos/Frameworks/ ==="
mkdir -p "$FRAMEWORKS_DIR"

# One-shot migration: the fork-era library this script used to produce. The
# Runner's embed phase globs macos/Frameworks/*.dylib, so a leftover copy would
# still be shipped. Safe to delete once no working tree predates piper-plus v2.
rm -f "$FRAMEWORKS_DIR/libpiper_tts_ffi.dylib"

# Only unversioned names are copied, with symlinks resolved (cp -L): upstream
# builds libpiper_plus with VERSION/SOVERSION, and ONNX Runtime ships versioned
# names too. Everything under macos/Frameworks/ gets embedded into the app
# bundle, so a versioned copy would be a byte-identical duplicate.
cp -L "$PIPER_DIR/build/libpiper_plus.dylib" "$FRAMEWORKS_DIR/libpiper_plus.dylib"

ORT_LIB="$PIPER_DIR/build/ort/lib/libonnxruntime.dylib"
if [ ! -f "$ORT_LIB" ]; then
    echo "ERROR: ONNX Runtime not found at $ORT_LIB" >&2
    exit 1
fi
cp -L "$ORT_LIB" "$FRAMEWORKS_DIR/libonnxruntime.dylib"
chmod u+w "$FRAMEWORKS_DIR/libpiper_plus.dylib" "$FRAMEWORKS_DIR/libonnxruntime.dylib"

# Fix install names
install_name_tool -id "@rpath/libpiper_plus.dylib" "$FRAMEWORKS_DIR/libpiper_plus.dylib"
install_name_tool -id "@rpath/libonnxruntime.dylib" "$FRAMEWORKS_DIR/libonnxruntime.dylib"

# Point piper_plus at the unversioned ONNX Runtime via @rpath
ORT_REF="$(otool -L "$FRAMEWORKS_DIR/libpiper_plus.dylib" | awk '/libonnxruntime/ {print $1}')"
if [ -n "$ORT_REF" ] && [ "$ORT_REF" != "@rpath/libonnxruntime.dylib" ]; then
    install_name_tool -change "$ORT_REF" "@rpath/libonnxruntime.dylib" \
        "$FRAMEWORKS_DIR/libpiper_plus.dylib"
fi

echo "=== Done ==="
echo "Shared libraries:"
echo "  $FRAMEWORKS_DIR/libpiper_plus.dylib"
echo "  $FRAMEWORKS_DIR/libonnxruntime.dylib"
echo ""
echo "The Runner target's 'Embed Native Libraries' phase copies and signs these"
echo "libraries into the .app, so no Xcode changes are needed."
