import Foundation
import SwiftData

/// SwiftData persistence for `DiagnosticIssue`.
///
/// Stored as primitives (toolIdRaw, severityRaw) rather than reference types
/// so the record survives schema drift in `ToolID` or `DiagnosticSeverity`
/// enum cases. The `severity` computed property does a safe lookup with a
/// `.info` fallback for unknown raw values.
///
/// Lives in `ForgeCore` (not `ForgeDiagnostics`) so `PersistenceController`
/// can register the schema without ForgeCore taking a dependency on
/// `ForgeDiagnostics`. The architecture document originally placed this file
/// in `ForgeDiagnostics`; the small deviation is recorded in the Phase 4B
/// commit message.
@Model
public final class DiagnosticIssueRecord {
    @Attribute(.unique) public var id: UUID
    public var toolIdRaw: String
    public var title: String
    public var explanation: String
    public var severityRaw: String
    public var estimatedSavingsBytes: UInt64?
    public var fixAvailable: Bool
    public var remediationText: String?
    public var lastAnalyzedAt: Date

    public init(
        id: UUID = UUID(),
        toolIdRaw: String,
        title: String,
        explanation: String,
        severityRaw: String,
        estimatedSavingsBytes: UInt64? = nil,
        fixAvailable: Bool = false,
        remediationText: String? = nil,
        lastAnalyzedAt: Date = Date()
    ) {
        self.id = id
        self.toolIdRaw = toolIdRaw
        self.title = title
        self.explanation = explanation
        self.severityRaw = severityRaw
        self.estimatedSavingsBytes = estimatedSavingsBytes
        self.fixAvailable = fixAvailable
        self.remediationText = remediationText
        self.lastAnalyzedAt = lastAnalyzedAt
    }
}

extension DiagnosticIssueRecord {
    /// Maps a `DiagnosticIssue` value type into a persisted record.
    /// `lastAnalyzedAt` is the same for every record produced by a single
    /// `analyze()` call so the UI can group issues by their snapshot time.
    public static func from(
        _ issue: DiagnosticIssue,
        lastAnalyzedAt: Date = Date()
    ) -> DiagnosticIssueRecord {
        DiagnosticIssueRecord(
            id: issue.id,
            toolIdRaw: issue.toolID.rawValue,
            title: issue.title,
            explanation: issue.explanation,
            severityRaw: issue.severity.rawValue,
            estimatedSavingsBytes: issue.estimatedSavingsBytes,
            fixAvailable: issue.fixAvailable,
            remediationText: issue.remediationText,
            lastAnalyzedAt: lastAnalyzedAt
        )
    }

    /// Safe severity lookup. Returns `.info` if the persisted raw value
    /// no longer maps to a known case (e.g. after enum renames).
    public var severity: DiagnosticSeverity {
        DiagnosticSeverity(rawValue: severityRaw) ?? .info
    }

    /// Maps back to a `DiagnosticIssue` value type for UI rendering.
    public func toIssue(toolID: ToolID) -> DiagnosticIssue {
        DiagnosticIssue(
            id: id,
            toolID: toolID,
            title: title,
            explanation: explanation,
            severity: severity,
            estimatedSavingsBytes: estimatedSavingsBytes,
            fixAvailable: fixAvailable,
            remediationText: remediationText
        )
    }
}
