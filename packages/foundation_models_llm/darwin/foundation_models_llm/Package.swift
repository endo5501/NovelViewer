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
        )
    ]
)
