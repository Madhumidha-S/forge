// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ForgeUtilities",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ForgeUtilities",
            targets: ["ForgeUtilities"]
        ),
    ],
    dependencies: [
        .package(path: "../ForgeCore")
    ],
    targets: [
        .target(
            name: "ForgeUtilities",
            dependencies: ["ForgeCore"]
        ),
        .testTarget(
            name: "ForgeUtilitiesTests",
            dependencies: ["ForgeUtilities", "ForgeCore"]
        ),
    ]
)
