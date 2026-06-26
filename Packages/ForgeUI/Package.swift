// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ForgeUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ForgeUI",
            targets: ["ForgeUI"]
        ),
    ],
    dependencies: [
        .package(path: "../ForgeCore"),
        .package(path: "../ForgeDetectors"),
    ],
    targets: [
        .target(
            name: "ForgeUI",
            dependencies: [
                .product(name: "ForgeCore", package: "ForgeCore"),
                .product(name: "ForgeDetectors", package: "ForgeDetectors"),
            ]
        ),
        .testTarget(
            name: "ForgeUITests",
            dependencies: ["ForgeUI"]
        ),
    ]
)
