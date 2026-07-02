import Foundation

/// A single issue raised by a `ToolDiagnostics` provider.
///
/// Lives in `ForgeCore` so the UI layer can render issues without depending
/// on `ForgeDiagnostics`. The diagnostics engine produces these; the UI
/// groups them by `severity` and surfaces `estimatedSavingsBytes` and
/// `remediationText` in the Diagnostics and Cleanup screens.
public struct DiagnosticIssue: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let toolID: ToolID
    public let title: String
    public let explanation: String
    public let severity: DiagnosticSeverity

    /// Estimated disk savings if the issue is fixed, in bytes.
    /// `nil` when the issue is not about reclaimable storage (e.g. config drift).
    public let estimatedSavingsBytes: UInt64?

    /// `true` if the diagnostics engine has a remediation registered.
    /// When `false`, `remediationText` is purely informational guidance.
    public let fixAvailable: Bool

    /// Short description of the recommended remediation.
    /// Shown in the Diagnostics screen and as the secondary line in the
    /// Cleanup preview. `nil` when the issue requires manual intervention.
    public let remediationText: String?

    public init(
        id: UUID = UUID(),
        toolID: ToolID,
        title: String,
        explanation: String,
        severity: DiagnosticSeverity,
        estimatedSavingsBytes: UInt64? = nil,
        fixAvailable: Bool = false,
        remediationText: String? = nil
    ) {
        self.id = id
        self.toolID = toolID
        self.title = title
        self.explanation = explanation
        self.severity = severity
        self.estimatedSavingsBytes = estimatedSavingsBytes
        self.fixAvailable = fixAvailable
        self.remediationText = remediationText
    }
}
