// swift-tools-version: 5.9
// ForgeDiagnostics — Developer Environment Intelligence Engine.
//
// Hosts the `DiagnosticsEngine` actor and per-tool `ToolDiagnostics`
// providers that scan the user's machine for storage, configuration, and
// hygiene issues. Pure value types (`DiagnosticSeverity`, `DiagnosticIssue`)
// live in `ForgeCore` so the UI layer can render issues without depending
// on this package.
//
// Phase 4A: package skeleton only. Providers land in Phase 4C–4D.
import PackageDescription

let package = Package(
    name: "ForgeDiagnostics",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ForgeDiagnostics",
            targets: ["ForgeDiagnostics"]
        ),
    ],
    dependencies: [
        .package(path: "../ForgeCore")
    ],
    targets: [
        .target(
            name: "ForgeDiagnostics",
            dependencies: ["ForgeCore"],
            path: "Sources/ForgeDiagnostics"
        ),
        .testTarget(
            name: "ForgeDiagnosticsTests",
            dependencies: ["ForgeDiagnostics"],
            path: "Tests/ForgeDiagnosticsTests"
        ),
    ]
)
