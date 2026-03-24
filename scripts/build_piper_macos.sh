#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PIPER_DIR="$PROJECT_ROOT/third_party/piper-plus"
FRAMEWORKS_DIR="$PROJECT_ROOT/macos/Frameworks"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

echo "=== Building piper_tts_ffi shared library (CPU only) ==="
mkdir -p "$PIPER_DIR/build"
cmake -S "$PIPER_DIR" -B "$PIPER_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPIPER_TTS_BUILD_SHARED=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build "$PIPER_DIR/build" --config Release --target piper_tts_ffi -j "$NUM_CORES"

echo "=== Copying shared libraries to macos/Frameworks/ ==="
mkdir -p "$FRAMEWORKS_DIR"
cp "$PIPER_DIR/build/libpiper_tts_ffi.dylib" "$FRAMEWORKS_DIR/"

# Copy ONNX Runtime shared library
ORT_LIB="$PIPER_DIR/build/ort/lib/libonnxruntime.dylib"
if [ -f "$ORT_LIB" ]; then
    # Copy the actual file (resolve symlink)
    cp -L "$ORT_LIB" "$FRAMEWORKS_DIR/libonnxruntime.dylib"
    # Also copy versioned dylib if exists
    for f in "$PIPER_DIR/build/ort/lib"/libonnxruntime.*.dylib; do
        [ -f "$f" ] && cp -L "$f" "$FRAMEWORKS_DIR/" || true
    done
fi

# Fix install names
install_name_tool -id "@rpath/libpiper_tts_ffi.dylib" "$FRAMEWORKS_DIR/libpiper_tts_ffi.dylib"
install_name_tool -id "@rpath/libonnxruntime.dylib" "$FRAMEWORKS_DIR/libonnxruntime.dylib" 2>/dev/null || true

# Fix piper_tts_ffi to find onnxruntime via @rpath
install_name_tool -change \
    "$(otool -L "$FRAMEWORKS_DIR/libpiper_tts_ffi.dylib" | grep libonnxruntime | awk '{print $1}')" \
    "@rpath/libonnxruntime.dylib" \
    "$FRAMEWORKS_DIR/libpiper_tts_ffi.dylib" 2>/dev/null || true

echo "=== Done ==="
echo "Shared libraries:"
echo "  $FRAMEWORKS_DIR/libpiper_tts_ffi.dylib"
echo "  $FRAMEWORKS_DIR/libonnxruntime.dylib"
echo ""
echo "Next: Add the libraries to Xcode as embedded frameworks."
echo "  1. Open macos/Runner.xcodeproj"
echo "  2. Select Runner target → General → Frameworks, Libraries, and Embedded Content"
echo "  3. Add libpiper_tts_ffi.dylib and libonnxruntime.dylib, set to 'Embed & Sign'"
