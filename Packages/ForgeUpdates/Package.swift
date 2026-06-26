// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ForgeUpdates",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ForgeUpdates",
            targets: ["ForgeUpdates"]
        ),
    ],
    dependencies: [
        .package(path: "../ForgeCore")
    ],
    targets: [
        .target(
            name: "ForgeUpdates",
            dependencies: ["ForgeCore"]
        ),
    ]
)
