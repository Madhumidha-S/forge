import Foundation

// Phase 4A placeholder. The real `DiagnosticsEngine` actor and the per-tool
// `ToolDiagnostics` providers land in Phase 4B and 4C–4D.
//
// This file exists so SPM treats the target as having at least one source;
// without it, `swift build` complains about an empty target.
public enum ForgeDiagnosticsPackage {
    public static let version = "0.4.0-phase4a"
}
