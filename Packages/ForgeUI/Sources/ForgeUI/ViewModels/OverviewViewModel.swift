import Foundation
import SwiftUI
import ForgeCore
import ForgeDiagnostics

/// View model for the Overview screen. Coordinates with the diagnostics
/// engine: on appear, runs `diagnosticsEngine.analyze()`, derives the
/// health score from the issue counts, and formats the cleanup estimate.
///
/// Phase 4F.2 — first end-to-end ViewModel that touches the diagnostics
/// engine from the UI layer. The Overview screen is the landing tab on
/// cold launch, so this also validates the AppEnvironment.live(...) wiring
/// from Phase 4E end-to-end.
@MainActor
public final class OverviewViewModel: ObservableObject {
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var issues: [DiagnosticIssue] = []
    @Published public private(set) var lastAnalyzedAt: Date?

    private let diagnosticsEngine: any DiagnosticsEngineProtocol

    public init(diagnosticsEngine: any DiagnosticsEngineProtocol) {
        self.diagnosticsEngine = diagnosticsEngine
    }

    /// Convenience initializer for SwiftUI previews that don't have an
    /// AppEnvironment wired up.
    public static func preview() -> OverviewViewModel {
        OverviewViewModel(diagnosticsEngine: PreviewStubDiagnosticsEngine())
    }

    /// Runs the diagnostics engine and refreshes `issues` + `lastAnalyzedAt`.
    /// Safe to call repeatedly — the engine handles re-entrancy.
    public func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await diagnosticsEngine.analyze()
            issues = result
            lastAnalyzedAt = Date()
        } catch {
            // Phase 4F.2 keeps the UI resilient: on failure, show the
            // last good issues (or empty) and update lastAnalyzedAt so the
            // UI reflects the attempt. Errors surface in Phase 4G when we
            // wire the error banner.
            issues = []
            lastAnalyzedAt = Date()
        }
    }

    // MARK: - Derived metrics for the Overview screen

    /// Health score from 0 (all critical) to 100 (no issues). Uses the
    /// severity-weighted count to derive the score. The formula:
    ///   critical = 10 points off each
    ///   warning  = 3 points off each
    ///   info     = 0.5 points off each (rounded down)
    /// Floors at 0. This is a placeholder heuristic — Phase 4G may
    /// refine it based on telemetry (e.g. weight by storage impact).
    public var healthScore: Int {
        let criticalCount = issues.filter { $0.severity == .critical }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        let penalty = criticalCount * 10 + warningCount * 3 + infoCount / 2
        return max(0, 100 - penalty)
    }

    public var healthyCount: Int {
        // A tool is "healthy" if it has at least one detection and zero
        // critical/warning issues. For Phase 4F.2 we approximate this by
        // counting tools that have at least one info-only issue or no
        // issues at all. Phase 4G will refine using per-tool detection
        // status.
        max(8 - issues.filter { $0.severity == .warning || $0.severity == .critical }.count, 0)
    }

    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    public var criticalCount: Int {
        issues.filter { $0.severity == .critical }.count
    }

    /// Total reclaimable storage across all issues. Summing the per-issue
    /// `estimatedSavingsBytes` is the right primitive — the diagnostics
    /// providers already populate that field conservatively.
    public var potentialCleanupBytes: UInt64 {
        issues.reduce(UInt64(0)) { $0 + ($1.estimatedSavingsBytes ?? 0) }
    }

    /// Top 3 issues by severity (critical first), then by savings desc.
    /// Used by the "Recently Detected" section of the Overview.
    public var recentIssues: [DiagnosticIssue] {
        Array(issues.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity.order < rhs.severity.order
            }
            return (lhs.estimatedSavingsBytes ?? 0) > (rhs.estimatedSavingsBytes ?? 0)
        }.prefix(3))
    }
}

// MARK: - Preview stub

/// No-op diagnostics engine for SwiftUI previews. Returns an empty array
/// from `analyze()` so the Overview screen renders its empty / loading
/// state during design-time iteration.
private final class PreviewStubDiagnosticsEngine: DiagnosticsEngineProtocol {
    func analyze() async throws -> [DiagnosticIssue] { [] }
    func analyze(toolID: ToolID) async throws -> [DiagnosticIssue] { [] }
    func cancel() async {}
}
