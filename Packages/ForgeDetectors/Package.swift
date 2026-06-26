// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ForgeDetectors",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ForgeDetectors",
            targets: ["ForgeDetectors"]
        ),
    ],
    dependencies: [
        .package(path: "../ForgeCore")
    ],
    targets: [
        .target(
            name: "ForgeDetectors",
            dependencies: ["ForgeCore"],
            path: "Sources/ForgeDetectors"
        ),
        .testTarget(
            name: "ForgeDetectorsTests",
            dependencies: ["ForgeDetectors"],
            path: "Tests/ForgeDetectorsTests"
        ),
    ]
)
