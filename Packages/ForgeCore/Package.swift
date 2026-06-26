// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ForgeCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ForgeCore",
            targets: ["ForgeCore"]
        ),
    ],
    targets: [
        .target(
            name: "ForgeCore",
            path: "Sources/ForgeCore"
        ),
        .testTarget(
            name: "ForgeCoreTests",
            dependencies: ["ForgeCore"],
            path: "Tests/ForgeCoreTests"
        ),
    ]
)
