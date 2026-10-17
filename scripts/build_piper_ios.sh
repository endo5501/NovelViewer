#!/bin/bash
set -euo pipefail

# Build piper-plus for iOS (device and simulator, both arm64) as
# ios/Frameworks/piper_plus.xcframework. See openspec change piper-ios-build,
# design D2-D4.
#
# Differences from build_piper_macos.sh:
# - The project's patches under patches/piper-plus/ are applied first. Upstream
#   v2.0.2 stubs out OpenJTalk on iOS, so Japanese text yields no phonemes
#   there. The patches are applied to an extracted copy of the submodule tree
#   (git archive), never to the submodule itself. When a patch no longer
#   applies, check whether upstream has shipped the fix and drop the patch.
# - Upstream builds a static archive on iOS. It is relinked here, together with
#   ONNX Runtime, into one dynamic framework that Dart opens with
#   DynamicLibrary.open. The iOS ONNX Runtime from Microsoft's CDN is itself a
#   static library, so no separate ONNX Runtime framework is shipped.
#
# The output is not tracked by Git: run this script before building the iOS app
# when TTS is needed. Without it, the iOS app still builds, without TTS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PIPER_DIR="$PROJECT_ROOT/third_party/piper-plus"
PATCH_DIR="$PROJECT_ROOT/patches/piper-plus"
WORK_DIR="$PROJECT_ROOT/build/piper-ios"
XCFRAMEWORK="$PROJECT_ROOT/ios/Frameworks/piper_plus.xcframework"

# Written into each framework's Info.plist as MinimumOSVersion too. Upstream
# builds iOS at 15.0; ONNX Runtime 1.20.0 requires 13.0.
DEPLOYMENT_TARGET="15.0"

# The ONNX Runtime version piper-plus v2.0.2 builds iOS against
# (cmake/OnnxRuntime.cmake, .github/workflows/release-shared-lib.yml), and the
# SHA-256 of Microsoft's CDN archive for it.
ORT_VERSION="1.20.0"
ORT_URL="https://download.onnxruntime.ai/pod-archive-onnxruntime-c-${ORT_VERSION}.zip"
ORT_SHA256="50891a8aadd17d4811acb05ed151ba6c394129bb3ab14e843b0fc83a48d450ff"

NUM_CORES=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

sha256_of() {
    shasum -a 256 "$1" | awk '{print $1}'
}

# fetch_ort : download (or reuse) the CDN archive, verify it, and lay out the
# arm64 static library and headers of each SDK under $WORK_DIR/ort/<sdk>.
fetch_ort() {
    local archive="$WORK_DIR/ort/onnxruntime-c-$ORT_VERSION.zip"
    mkdir -p "$WORK_DIR/ort"

    if [ -f "$archive" ] && [ "$(sha256_of "$archive")" != "$ORT_SHA256" ]; then
        echo "Cached ONNX Runtime archive does not match; downloading again."
        rm -f "$archive"
    fi
    if [ ! -f "$archive" ]; then
        echo "=== Downloading ONNX Runtime $ORT_VERSION ==="
        curl -fsSL --retry 3 -o "$archive.part" "$ORT_URL"
        mv "$archive.part" "$archive"
    fi

    local actual
    actual="$(sha256_of "$archive")"
    if [ "$actual" != "$ORT_SHA256" ]; then
        echo "ERROR: ONNX Runtime archive SHA-256 mismatch" >&2
        echo "  expected: $ORT_SHA256" >&2
        echo "  actual:   $actual" >&2
        rm -f "$archive"
        exit 1
    fi

    rm -rf "$WORK_DIR/ort/extracted"
    unzip -q "$archive" -d "$WORK_DIR/ort/extracted"
    local xcf="$WORK_DIR/ort/extracted/onnxruntime.xcframework"

    # sdk -> slice of Microsoft's xcframework. The simulator slice is universal
    # (arm64 + x86_64); only arm64 is kept.
    local sdk slice
    for sdk in iphoneos iphonesimulator; do
        case "$sdk" in
            iphoneos) slice="ios-arm64" ;;
            iphonesimulator) slice="ios-arm64_x86_64-simulator" ;;
        esac
        rm -rf "$WORK_DIR/ort/$sdk"
        mkdir -p "$WORK_DIR/ort/$sdk/lib" "$WORK_DIR/ort/$sdk/include"
        lipo -thin arm64 "$xcf/$slice/onnxruntime.framework/onnxruntime" \
            -output "$WORK_DIR/ort/$sdk/lib/libonnxruntime.a"
        cp "$xcf/$slice/onnxruntime.framework/Headers/"*.h "$WORK_DIR/ort/$sdk/include/"
    done
}

# prepare_source : extract the pinned submodule tree and apply the patches.
prepare_source() {
    local src="$WORK_DIR/src"

    if [ ! -f "$PIPER_DIR/CMakeLists.txt" ]; then
        echo "ERROR: $PIPER_DIR is empty; run git submodule update --init" >&2
        exit 1
    fi

    echo "=== Extracting piper-plus $(git -C "$PIPER_DIR" describe --tags --always) ==="
    rm -rf "$src"
    mkdir -p "$src"
    git -C "$PIPER_DIR" archive HEAD | tar -x -C "$src"
    # Its own repository, so git apply resolves paths against this tree rather
    # than against NovelViewer, which build/ lives in.
    git -C "$src" init -q

    local patch
    for patch in "$PATCH_DIR"/*.patch; do
        [ -f "$patch" ] || continue
        echo "Applying $(basename "$patch")"
        if ! git -C "$src" apply "$patch"; then
            echo "ERROR: patch $(basename "$patch") does not apply to piper-plus" \
                "$(git -C "$PIPER_DIR" describe --tags --always)." >&2
            echo "If upstream has shipped the fix, delete the patch." >&2
            exit 1
        fi
    done
}

# build_sdk <sdk> : configure and build the static piper_plus archive.
build_sdk() {
    local sdk="$1"
    local ort="$WORK_DIR/ort/$sdk"

    echo "=== Building piper_plus for $sdk ==="
    cmake -S "$WORK_DIR/src" -B "$WORK_DIR/build-$sdk" \
        -DCMAKE_TOOLCHAIN_FILE="$WORK_DIR/src/cmake/ios.toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_SYSROOT="$sdk" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DPIPER_PLUS_BUILD_SHARED=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DONNXRUNTIME_DIR="$ort" \
        -DONNXRUNTIME_LIB="$ort/lib/libonnxruntime.a" \
        -DONNXRUNTIME_INCLUDE_DIR="$ort/include"
    ZERO_AR_DATE=1 cmake --build "$WORK_DIR/build-$sdk" --config Release \
        --target piper_plus -j "$NUM_CORES"
}

# framework_path <sdk> : where make_framework assembles that SDK's framework.
framework_path() {
    echo "$WORK_DIR/framework-$1/piper_plus.framework"
}

# make_framework <sdk> <target-triple> <supported-platform> : link the archive
# and ONNX Runtime into one dylib and wrap it as a flat iOS framework.
#
# Called directly, never inside $(...): bash drops errexit in command
# substitutions (and macOS's bash 3.2 has no inherit_errexit), so a failing
# step there would go unnoticed.
make_framework() {
    local sdk="$1" target="$2" platform="$3"
    local framework
    framework="$(framework_path "$sdk")"

    rm -rf "$framework"
    mkdir -p "$framework"

    # -force_load keeps every C API function, which nothing in the dylib itself
    # references. Only piper_plus_* is exported: archives ignore visibility, so
    # ONNX Runtime, fmt, spdlog and OpenJTalk would otherwise leak out.
    # Foundation is what ONNX Runtime's CoreML provider needs from the system.
    xcrun --sdk "$sdk" clang++ -dynamiclib \
        -target "$target" \
        -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
        -Wl,-force_load,"$WORK_DIR/build-$sdk/libpiper_plus.a" \
        "$WORK_DIR/ort/$sdk/lib/libonnxruntime.a" \
        -Wl,-exported_symbol,'_piper_plus_*' \
        -Wl,-dead_strip \
        -framework Foundation \
        -install_name "@rpath/piper_plus.framework/piper_plus" \
        -o "$framework/piper_plus"
    # Local symbols only; the exported C API is kept.
    strip -x "$framework/piper_plus"

    cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>piper_plus</string>
    <key>CFBundleIdentifier</key>
    <string>com.endo5501.novelViewer.piper-plus</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>piper_plus</string>
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

fetch_ort
prepare_source
build_sdk iphoneos
build_sdk iphonesimulator

echo "=== Assembling piper_plus.xcframework ==="
make_framework iphoneos "arm64-apple-ios$DEPLOYMENT_TARGET" iPhoneOS
make_framework iphonesimulator "arm64-apple-ios$DEPLOYMENT_TARGET-simulator" iPhoneSimulator

# Assembled beside the destination and swapped in only once complete, so a
# failure anywhere above leaves the previous xcframework untouched.
# -create-xcframework also refuses to overwrite.
STAGED="$WORK_DIR/staged/piper_plus.xcframework"
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
echo "Verify with: scripts/test/verify_piper_ios.sh"
