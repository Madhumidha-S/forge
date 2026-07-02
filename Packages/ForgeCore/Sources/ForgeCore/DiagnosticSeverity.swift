import Foundation

/// Severity of a `DiagnosticIssue` raised by the diagnostics engine.
///
/// Lives in `ForgeCore` (not `ForgeDiagnostics`) so the UI layer can render
/// issues without depending on the diagnostics package — the value type is
/// the contract the UI binds to.
public enum DiagnosticSeverity: String, Sendable, Codable, CaseIterable, Hashable {
    /// Informational note — no action required, but worth surfacing.
    case info
    /// Warning — a real issue, not yet critical. Worth surfacing and ideally fixing.
    case warning
    /// Critical — blocking issue. Should be the first thing the user sees.
    case critical
}
