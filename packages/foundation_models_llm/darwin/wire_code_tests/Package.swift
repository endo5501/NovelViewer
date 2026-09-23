// swift-tools-version: 5.9
import PackageDescription

// The plugin's own package depends on FlutterFramework, which only exists
// inside a Flutter build, so `swift test` cannot run there. The wire-code
// mapping needs nothing from Flutter, so this package compiles that one
// source file — symlinked, not copied, so there is one definition — and
// tests it on its own:
//
//   swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests
let package = Package(
    name: "wire_code_tests",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    targets: [
        .target(name: "GenerationFailureWireCode"),
        .testTarget(
            name: "GenerationFailureWireCodeTests",
            dependencies: ["GenerationFailureWireCode"]
        ),
    ]
)
