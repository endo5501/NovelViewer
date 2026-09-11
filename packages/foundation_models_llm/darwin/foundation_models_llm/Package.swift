// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "foundation_models_llm",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "foundation-models-llm", targets: ["foundation_models_llm"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "foundation_models_llm",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
            // No explicit weak-link setting for FoundationModels. The linker
            // weak-links a framework whose availability is newer than the
            // deployment target on its own, which was confirmed on a built
            // binary: `otool -l` reports LC_LOAD_WEAK_DYLIB for it in both
            // the iOS and macOS products. The CocoaPods path says the same
            // thing explicitly, via `s.weak_frameworks` in the podspec.
        )
    ]
)
