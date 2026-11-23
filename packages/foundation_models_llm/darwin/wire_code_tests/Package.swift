// swift-tools-version: 5.9
import PackageDescription

// The plugin's own package depends on FlutterFramework, which only exists
// inside a Flutter build, so `swift test` cannot run there. The wire-code
// mapping, the answer cut-off and the generation options need nothing from
// Flutter, so this package compiles those source files — symlinked, not
// copied, so there is one definition of each — and tests them on their own:
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
        .target(name: "AnswerCutoff"),
        .testTarget(
            name: "AnswerCutoffTests",
            dependencies: ["AnswerCutoff"]
        ),
        // Warnings are errors here so a deprecated framework call in this
        // file fails the build rather than scrolling past in it. The plugin
        // file itself is not built here, so it is not covered; keep the
        // options it uses inside this file. Only a root package may use
        // unsafe flags, which this one always is.
        .target(
            name: "GenerationOptionsFactory",
            swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
        ),
        .testTarget(
            name: "GenerationOptionsFactoryTests",
            dependencies: ["GenerationOptionsFactory"]
        ),
    ]
)
