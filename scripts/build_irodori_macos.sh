#!/bin/bash
set -euo pipefail

# Build the audio.cpp Irodori-TTS FFI shared library (libaudiocpp_ffi.dylib)
# with the Metal backend and copy it into macos/Frameworks. Mirrors
# build_tts_macos.sh.
#
# The model spec is compiled into the library (AUDIOCPP_DEPLOYMENT_BUILD)
# rather than shipped beside it: Contents/Frameworks is sealed by codesign, so
# a stray .json there fails the signature (see openspec design D3).
#
# Requires Homebrew's libomp: AppleClang ships no OpenMP runtime, and
# audio.cpp's CMake declares find_package(OpenMP REQUIRED). We point CMake at
# libomp.a rather than the dylib so the resulting library has no dependency
# outside the .app bundle (see openspec design D1).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUDIO_DIR="$PROJECT_ROOT/third_party/audio.cpp"
BUILD_DIR="$AUDIO_DIR/build/ffi-metal"
FRAMEWORKS_DIR="$PROJECT_ROOT/macos/Frameworks"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

echo "=== Checking for Homebrew libomp ==="
# `brew --prefix libomp` exits non-zero when the formula is not installed; the
# `|| true` keeps `set -e` from aborting before we can print a useful message.
OMP_PREFIX="$(brew --prefix libomp 2>/dev/null || true)"
if [ -z "$OMP_PREFIX" ] || [ ! -f "$OMP_PREFIX/lib/libomp.a" ]; then
    echo "error: libomp not found."
    echo "  audio.cpp requires OpenMP, which AppleClang does not bundle."
    echo "  Install it with:  brew install libomp"
    exit 1
fi
echo "libomp: $OMP_PREFIX"

echo "=== Configuring audio.cpp (Metal + shared FFI) ==="
# Setting OpenMP_*_FLAGS and OpenMP_*_LIB_NAMES makes FindOpenMP skip its own
# probing and take these values verbatim, which lets us substitute the static
# libomp.a for the keg-only dylib CMake would otherwise fail to locate.
cmake -S "$AUDIO_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENGINE_ENABLE_METAL=ON \
    -DENGINE_ENABLE_OPENMP=ON \
    -DAUDIOCPP_BUILD_SHARED=ON \
    -DENGINE_BUILD_TESTS=OFF \
    -DAUDIOCPP_DEPLOYMENT_BUILD=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DOpenMP_C_FLAGS="-Xclang -fopenmp -I$OMP_PREFIX/include" \
    -DOpenMP_CXX_FLAGS="-Xclang -fopenmp -I$OMP_PREFIX/include" \
    -DOpenMP_C_LIB_NAMES=libomp \
    -DOpenMP_CXX_LIB_NAMES=libomp \
    -DOpenMP_libomp_LIBRARY="$OMP_PREFIX/lib/libomp.a"

echo "=== Building audiocpp_ffi ==="
cmake --build "$BUILD_DIR" --config Release --target audiocpp_ffi -j "$NUM_CORES"

echo "=== Copying shared library to macos/Frameworks/ ==="
mkdir -p "$FRAMEWORKS_DIR"

DYLIB_SRC="$BUILD_DIR/bin/libaudiocpp_ffi.dylib"
if [ ! -f "$DYLIB_SRC" ]; then
    DYLIB_SRC="$BUILD_DIR/libaudiocpp_ffi.dylib"
fi
cp "$DYLIB_SRC" "$FRAMEWORKS_DIR/"

# Fix install name so the app can find the library at runtime.
install_name_tool -id "@rpath/libaudiocpp_ffi.dylib" "$FRAMEWORKS_DIR/libaudiocpp_ffi.dylib"

# One-shot migration: earlier revisions of this script copied the spec here, and
# a leftover directory breaks CodeSign ("code object is not signed at all" —
# Frameworks is sealed). Safe to delete once no working tree predates the switch
# to AUDIOCPP_DEPLOYMENT_BUILD.
rm -rf "$FRAMEWORKS_DIR/model_specs"

echo "=== Done ==="
echo "Shared library: $FRAMEWORKS_DIR/libaudiocpp_ffi.dylib"
echo "Model spec:     compiled into the library (AUDIOCPP_DEPLOYMENT_BUILD)"
echo ""
echo "The Runner target's 'Embed Native Libraries' phase copies and signs this"
echo "library into the .app, so no Xcode changes are needed."
echo "Verify with: scripts/test/verify_irodori_macos.sh"
