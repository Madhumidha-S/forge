// swift-tools-version: 5.9
// ForgeDesign — design system tokens (typography, spacing, colors, materials,
// surface views) for the Forge app.
//
// Depends only on SwiftUI so the design system can be iterated independently
// from domain types. Concrete tokens (Typography, Spacing, Radius, Palette,
// Materials, Surfaces, ViewModifiers) land in Phase 4E alongside the app
// shell; this Phase 4A commit is just the package skeleton.
import PackageDescription

let package = Package(
    name: "ForgeDesign",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ForgeDesign",
            targets: ["ForgeDesign"]
        ),
    ],
    targets: [
        .target(
            name: "ForgeDesign",
            path: "Sources/ForgeDesign"
        ),
        .testTarget(
            name: "ForgeDesignTests",
            dependencies: ["ForgeDesign"],
            path: "Tests/ForgeDesignTests"
        ),
    ]
)
