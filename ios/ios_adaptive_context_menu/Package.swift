// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ios_adaptive_context_menu",
    platforms: [
        .iOS("14.0")
    ],
    products: [
        .library(
            name: "ios-adaptive-context-menu",
            targets: ["ios_adaptive_context_menu"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "ios_adaptive_context_menu",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
