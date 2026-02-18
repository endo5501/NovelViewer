#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TTS_DIR="$PROJECT_ROOT/third_party/qwen3-tts.cpp"
GGML_DIR="$TTS_DIR/ggml"
FRAMEWORKS_DIR="$PROJECT_ROOT/macos/Frameworks"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

echo "=== Building GGML (Metal enabled) ==="
mkdir -p "$GGML_DIR/build"
cmake -S "$GGML_DIR" -B "$GGML_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build "$GGML_DIR/build" --config Release -j "$NUM_CORES"

echo "=== Building qwen3_tts_ffi shared library ==="
mkdir -p "$TTS_DIR/build"
cmake -S "$TTS_DIR" -B "$TTS_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DQWEN3_TTS_BUILD_SHARED=ON \
    -DQWEN3_TTS_COREML=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build "$TTS_DIR/build" --config Release --target qwen3_tts_ffi -j "$NUM_CORES"

echo "=== Copying shared library to macos/Frameworks/ ==="
mkdir -p "$FRAMEWORKS_DIR"
cp "$TTS_DIR/build/libqwen3_tts_ffi.dylib" "$FRAMEWORKS_DIR/"

# Fix install name so the app can find the library at runtime
install_name_tool -id "@rpath/libqwen3_tts_ffi.dylib" "$FRAMEWORKS_DIR/libqwen3_tts_ffi.dylib"

echo "=== Done ==="
echo "Shared library: $FRAMEWORKS_DIR/libqwen3_tts_ffi.dylib"
echo ""
echo "Next: Add the library to Xcode as an embedded framework."
echo "  1. Open macos/Runner.xcodeproj"
echo "  2. Select Runner target → General → Frameworks, Libraries, and Embedded Content"
echo "  3. Add libqwen3_tts_ffi.dylib and set to 'Embed & Sign'"
