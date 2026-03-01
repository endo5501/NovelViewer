#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAME_FFI_DIR="$PROJECT_ROOT/third_party/lame_enc_ffi"
FRAMEWORKS_DIR="$PROJECT_ROOT/macos/Frameworks"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

echo "=== Building lame_enc_ffi shared library ==="
mkdir -p "$LAME_FFI_DIR/build"
cmake -S "$LAME_FFI_DIR" -B "$LAME_FFI_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$LAME_FFI_DIR/build" --config Release -j "$NUM_CORES"

echo "=== Copying dylib to macos/Frameworks/ ==="
mkdir -p "$FRAMEWORKS_DIR"
cp "$LAME_FFI_DIR/build/liblame_enc_ffi.dylib" "$FRAMEWORKS_DIR/"

# Fix install name so the app can find the library at runtime
install_name_tool -id "@rpath/liblame_enc_ffi.dylib" "$FRAMEWORKS_DIR/liblame_enc_ffi.dylib"

echo "=== Done ==="
echo "Shared library: $FRAMEWORKS_DIR/liblame_enc_ffi.dylib"
echo ""
echo "Next: Add the library to Xcode as an embedded framework."
echo "  1. Open macos/Runner.xcodeproj"
echo "  2. Select Runner target -> General -> Frameworks, Libraries, and Embedded Content"
echo "  3. Add liblame_enc_ffi.dylib and set to 'Embed & Sign'"
