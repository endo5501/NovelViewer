#!/bin/bash
set -euo pipefail

# Build the audio.cpp Irodori-TTS FFI shared library (libaudiocpp_ffi.dylib)
# with the Metal backend and copy it, plus the model spec, into macos/Frameworks.
# Mirrors build_tts_macos.sh. Not tested on this project's CI yet.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUDIO_DIR="$PROJECT_ROOT/third_party/audio.cpp"
BUILD_DIR="$AUDIO_DIR/build/ffi-metal"
FRAMEWORKS_DIR="$PROJECT_ROOT/macos/Frameworks"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

echo "=== Configuring audio.cpp (Metal + shared FFI) ==="
cmake -S "$AUDIO_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENGINE_ENABLE_METAL=ON \
    -DENGINE_ENABLE_OPENMP=ON \
    -DAUDIOCPP_BUILD_SHARED=ON \
    -DENGINE_BUILD_TESTS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON

echo "=== Building audiocpp_ffi ==="
cmake --build "$BUILD_DIR" --config Release --target audiocpp_ffi -j "$NUM_CORES"

echo "=== Copying shared library and model spec to macos/Frameworks/ ==="
mkdir -p "$FRAMEWORKS_DIR"

DYLIB_SRC="$BUILD_DIR/bin/libaudiocpp_ffi.dylib"
if [ ! -f "$DYLIB_SRC" ]; then
    DYLIB_SRC="$BUILD_DIR/libaudiocpp_ffi.dylib"
fi
cp "$DYLIB_SRC" "$FRAMEWORKS_DIR/"

# Fix install name so the app can find the library at runtime.
install_name_tool -id "@rpath/libaudiocpp_ffi.dylib" "$FRAMEWORKS_DIR/libaudiocpp_ffi.dylib"

# The shim resolves model_specs/irodori_tts.json next to the dylib itself.
mkdir -p "$FRAMEWORKS_DIR/model_specs"
cp "$AUDIO_DIR/model_specs/irodori_tts.json" "$FRAMEWORKS_DIR/model_specs/"

echo "=== Done ==="
echo "Shared library: $FRAMEWORKS_DIR/libaudiocpp_ffi.dylib"
echo "Model spec:     $FRAMEWORKS_DIR/model_specs/irodori_tts.json"
echo ""
echo "Next: Add the library to Xcode as an embedded framework."
echo "  1. Open macos/Runner.xcodeproj"
echo "  2. Select Runner target -> General -> Frameworks, Libraries, and Embedded Content"
echo "  3. Add libaudiocpp_ffi.dylib and set to 'Embed & Sign'"
