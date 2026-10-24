#!/bin/bash
set -euo pipefail

# Build speech.cpp for iOS (device and simulator, both arm64) as
# ios/Frameworks/speech_cpp.xcframework. See openspec change
# speech-cpp-ios-spike, design D2-D4.
#
# Upstream builds on iOS with standard ggml options and no source changes:
# - Metal is on, with the shader source compiled into the library
#   (GGML_METAL_EMBED_LIBRARY), since the app ships no default.metallib.
# - GGML_NATIVE=OFF: it probes the host CPU, which is wrong when
#   cross-compiling.
# - OpenMP and BLAS are off: there is no libomp for iOS, and ggml computes on
#   Metal.
# Only the shared library target is built; the speech CLI cannot run on iOS.
#
# The library is renamed from libspeech to speech_cpp so it cannot be confused
# with Apple's Speech.framework (design D2).
#
# The output is not tracked by Git. Irodori-TTS runs on it in the iOS app, so
# keep it in ios/Frameworks/ for an app build that offers Irodori-TTS; the
# on-device measurement in integration_test/speech_cpp_ios_test.dart uses it
# too.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SPEECH_DIR="$PROJECT_ROOT/third_party/speech.cpp"
WORK_DIR="$PROJECT_ROOT/build/speech-ios"
XCFRAMEWORK="$PROJECT_ROOT/ios/Frameworks/speech_cpp.xcframework"

# Written into each framework's Info.plist as MinimumOSVersion too. It matches
# the Runner's IPHONEOS_DEPLOYMENT_TARGET, which the framework must not exceed
# (design D3).
DEPLOYMENT_TARGET="15.0"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

if [ ! -f "$SPEECH_DIR/CMakeLists.txt" ] || [ ! -f "$SPEECH_DIR/ggml/CMakeLists.txt" ]; then
    echo "Error: speech.cpp or its ggml submodule is missing." >&2
    echo "Run: git submodule update --init --recursive third_party/speech.cpp" >&2
    exit 1
fi

# build_sdk <sdk> : configure and build the speech shared library for one SDK.
# The build directory is outside the submodule, so its working tree stays clean.
build_sdk() {
    local sdk="$1"
    local build_dir="$WORK_DIR/$sdk"

    echo "=== Configuring speech.cpp for $sdk (Metal, embedded shaders) ==="
    cmake -S "$SPEECH_DIR" -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT="$sdk" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DGGML_METAL=ON \
        -DGGML_METAL_EMBED_LIBRARY=ON \
        -DGGML_NATIVE=OFF \
        -DGGML_OPENMP=OFF \
        -DGGML_BLAS=OFF

    echo "=== Building libspeech for $sdk ==="
    cmake --build "$build_dir" --config Release --target speech -j "$NUM_CORES"
}

# framework_path <sdk> : where make_framework assembles that SDK's framework.
framework_path() {
    echo "$WORK_DIR/framework-$1/speech_cpp.framework"
}

# make_framework <sdk> <supported-platform> : wrap one SDK's dylib as a flat
# iOS framework (binary + Info.plist) at framework_path.
#
# Called directly, never inside $(...): bash drops errexit in command
# substitutions (and macOS's bash 3.2 has no inherit_errexit), so a failing
# step there would go unnoticed.
make_framework() {
    local sdk="$1" platform="$2"
    local build_dir="$WORK_DIR/$sdk"
    local framework
    framework="$(framework_path "$sdk")"

    rm -rf "$framework"
    mkdir -p "$framework"
    # libspeech.dylib is a symlink to the versioned file; -L copies the binary.
    cp -L "$build_dir/libspeech.dylib" "$framework/speech_cpp"
    # Dart opens "speech_cpp.framework/speech_cpp", resolved through the
    # Runner's @executable_path/Frameworks rpath.
    install_name_tool -id "@rpath/speech_cpp.framework/speech_cpp" "$framework/speech_cpp"

    cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>speech_cpp</string>
    <key>CFBundleIdentifier</key>
    <string>com.endo5501.novelViewer.speech-cpp</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>speech_cpp</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>$platform</string>
    </array>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>$DEPLOYMENT_TARGET</string>
</dict>
</plist>
PLIST
}

build_sdk iphoneos
build_sdk iphonesimulator

echo "=== Assembling speech_cpp.xcframework ==="
make_framework iphoneos iPhoneOS
make_framework iphonesimulator iPhoneSimulator

# Assembled beside the build and moved into place only once complete, so a
# failure anywhere above leaves the existing xcframework untouched, and no
# slice from an earlier run survives the replacement.
STAGED="$WORK_DIR/staged/speech_cpp.xcframework"
rm -rf "$WORK_DIR/staged"
xcodebuild -create-xcframework \
    -framework "$(framework_path iphoneos)" \
    -framework "$(framework_path iphonesimulator)" \
    -output "$STAGED"

mkdir -p "$(dirname "$XCFRAMEWORK")"
rm -rf "$XCFRAMEWORK"
mv "$STAGED" "$XCFRAMEWORK"

echo "=== Done ==="
echo "xcframework: $XCFRAMEWORK"
echo ""
echo "The Runner target's 'Embed Native Frameworks' phase copies and signs the"
echo "matching slice into the .app, so no Xcode changes are needed."
echo "Verify with: scripts/test/verify_speech_ios.sh"
